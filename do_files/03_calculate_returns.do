/*==============================================================================
Comprehensive Event Study Toolkit: Return Calculations
================================================================================

Purpose: Calculate stock returns, market returns, and abnormal returns using
         various methodologies. Implements market model, market-adjusted returns,
         and other abnormal return calculation methods.

Author: Comprehensive Event Study Toolkit
Date: Created for academic and professional event study analysis

Input Files:
- data/processed/event_windows.dta
- data/processed/event_data_clean.dta (for return data)

Output Files:
- data/processed/abnormal_returns.dta

Notes:
- Implements multiple abnormal return calculation methods
- Handles missing return data appropriately
- Calculates cumulative abnormal returns for various windows
- Provides statistical significance tests

==============================================================================*/

// Ensure setup has been run
if "${main_dir}" == "" {
    display as error "Please run 00_setup.do first"
    exit
}

display as text _newline "=== Return Calculations ==="
display as text "Calculating abnormal returns using various methodologies..."

/*------------------------------------------------------------------------------
1. Load Event Windows and Merge with Return Data
------------------------------------------------------------------------------*/

display as text _newline "1. Loading event windows and return data..."

use "${processed}/event_windows.dta", clear

// Merge with original data to get return information
merge m:1 event_id using "${processed}/event_data_clean.dta", ///
    keep(match master) nogen

display as text "Event windows with return data: `c(N)' observations"

/*------------------------------------------------------------------------------
2. Identify Return Variables
------------------------------------------------------------------------------*/

display as text _newline "2. Identifying return and price variables..."

// Look for return variables
local return_vars ""
foreach var of varlist _all {
    local var_lower = lower("`var'")
    if regexm("`var_lower'", "ret|return") & !regexm("`var_lower'", "abnormal|car|ar") {
        local return_vars "`return_vars' `var'"
    }
}

// Look for price variables
local price_vars ""
foreach var of varlist _all {
    local var_lower = lower("`var'")
    if regexm("`var_lower'", "price|prc") {
        local price_vars "`price_vars' `var'"
    }
}

display as text "Potential return variables: `return_vars'"
display as text "Potential price variables: `price_vars'"

// Use the first return variable found
local return_var : word 1 of `return_vars'
if "`return_var'" == "" {
    // If no return variable, try to calculate from price
    local price_var : word 1 of `price_vars'
    if "`price_var'" != "" {
        display as text "No return variable found, calculating from price: `price_var'"
        sort firm_id calendar_date
        by firm_id: gen stock_return = (`price_var' / `price_var'[_n-1]) - 1
    }
    else {
        display as text "No return or price variables found, using simulated returns for demonstration"
        set seed 12345
        gen stock_return = rnormal(0, 0.02)
    }
}
else {
    display as text "Using return variable: `return_var'"
    gen stock_return = `return_var'
}

/*------------------------------------------------------------------------------
3. Calculate Market Returns
------------------------------------------------------------------------------*/

display as text _newline "3. Calculating market returns..."

// Calculate value-weighted market return if market cap available
local mktcap_vars ""
foreach var of varlist _all {
    local var_lower = lower("`var'")
    if regexm("`var_lower'", "mktcap|market_cap|mcap|total_assets") {
        local mktcap_vars "`mktcap_vars' `var'"
    }
}

local mktcap_var : word 1 of `mktcap_vars'

if "`mktcap_var'" != "" {
    display as text "Calculating value-weighted market return using: `mktcap_var'"
    
    // Calculate value-weighted market return by date
    preserve
        collapse (mean) vw_market_return = stock_return [aweight=`mktcap_var'], ///
            by(calendar_date)
        tempfile market_returns
        save `market_returns'
    restore
    
    merge m:1 calendar_date using `market_returns', keep(match master) nogen
}
else {
    display as text "No market cap variable found, calculating equal-weighted market return"
    
    // Calculate equal-weighted market return by date
    preserve
        collapse (mean) ew_market_return = stock_return, by(calendar_date)
        tempfile market_returns
        save `market_returns'
    restore
    
    merge m:1 calendar_date using `market_returns', keep(match master) nogen
    gen vw_market_return = ew_market_return
}

/*------------------------------------------------------------------------------
4. Estimate Market Model Parameters
------------------------------------------------------------------------------*/

display as text _newline "4. Estimating market model parameters..."

// Keep only estimation window observations for parameter estimation
preserve
    keep if estimation_window == 1
    
    // Estimate market model for each firm
    gen alpha = .
    gen beta = .
    gen r_squared = .
    gen residual_variance = .
    
    levelsof firm_id, local(firms)
    local count = 0
    
    foreach firm of local firms {
        local count = `count' + 1
        if mod(`count', 100) == 0 {
            display as text "Processing firm `count' of `=wordcount("`firms'")'"
        }
        
        capture {
            regress stock_return vw_market_return if firm_id == `firm'
            
            if e(N) >= ${min_observations} {
                replace alpha = _b[_cons] if firm_id == `firm'
                replace beta = _b[vw_market_return] if firm_id == `firm'
                replace r_squared = e(r2) if firm_id == `firm'
                replace residual_variance = e(rmse)^2 if firm_id == `firm'
            }
        }
    }
    
    // Keep only firm-level parameters
    collapse (first) alpha beta r_squared residual_variance, by(firm_id)
    
    tempfile market_model_params
    save `market_model_params'
restore

// Merge market model parameters back to main dataset
merge m:1 firm_id using `market_model_params', keep(match master) nogen

/*------------------------------------------------------------------------------
5. Calculate Abnormal Returns
------------------------------------------------------------------------------*/

display as text _newline "5. Calculating abnormal returns..."

// Market model abnormal returns
gen ar_market_model = stock_return - (alpha + beta * vw_market_return)

// Market-adjusted abnormal returns
gen ar_market_adjusted = stock_return - vw_market_return

// Mean-adjusted abnormal returns (using estimation period mean)
preserve
    keep if estimation_window == 1
    collapse (mean) mean_return = stock_return, by(firm_id)
    tempfile mean_returns
    save `mean_returns'
restore

merge m:1 firm_id using `mean_returns', keep(match master) nogen
gen ar_mean_adjusted = stock_return - mean_return

/*------------------------------------------------------------------------------
6. Calculate Cumulative Abnormal Returns
------------------------------------------------------------------------------*/

display as text _newline "6. Calculating cumulative abnormal returns..."

// Sort by event and day
sort event_id event_day

// Calculate CARs for different windows and methods
foreach method in market_model market_adjusted mean_adjusted {
    
    // CAR [-1,+1]
    by event_id: egen car_1_`method' = total(ar_`method') if event_window_1 == 1
    by event_id: egen temp = max(car_1_`method')
    replace car_1_`method' = temp
    drop temp
    
    // CAR [-3,+3]
    by event_id: egen car_3_`method' = total(ar_`method') if event_window_3 == 1
    by event_id: egen temp = max(car_3_`method')
    replace car_3_`method' = temp
    drop temp
    
    // CAR [-5,+5]
    by event_id: egen car_5_`method' = total(ar_`method') if event_window_5 == 1
    by event_id: egen temp = max(car_5_`method')
    replace car_5_`method' = temp
    drop temp
    
    // CAR [-10,+10]
    by event_id: egen car_10_`method' = total(ar_`method') if event_window_10 == 1
    by event_id: egen temp = max(car_10_`method')
    replace car_10_`method' = temp
    drop temp
}

/*------------------------------------------------------------------------------
7. Calculate Statistical Significance
------------------------------------------------------------------------------*/

display as text _newline "7. Calculating statistical significance..."

// Calculate standard errors for abnormal returns
foreach method in market_model market_adjusted mean_adjusted {
    
    // Standard error of abnormal returns
    gen se_ar_`method' = sqrt(residual_variance) if !missing(residual_variance)
    
    // T-statistics for abnormal returns
    gen t_ar_`method' = ar_`method' / se_ar_`method'
    
    // P-values (two-tailed)
    gen p_ar_`method' = 2 * (1 - normal(abs(t_ar_`method')))
    
    // Significance indicators
    gen sig_ar_`method' = (p_ar_`method' < 0.05)
}

/*------------------------------------------------------------------------------
8. Add Variable Labels
------------------------------------------------------------------------------*/

display as text _newline "8. Adding variable labels..."

label var stock_return "Stock return"
label var vw_market_return "Value-weighted market return"
label var alpha "Market model alpha"
label var beta "Market model beta"
label var r_squared "Market model R-squared"

foreach method in market_model market_adjusted mean_adjusted {
    label var ar_`method' "Abnormal return (`method')"
    label var car_1_`method' "CAR [-1,+1] (`method')"
    label var car_3_`method' "CAR [-3,+3] (`method')"
    label var car_5_`method' "CAR [-5,+5] (`method')"
    label var car_10_`method' "CAR [-10,+10] (`method')"
    label var t_ar_`method' "T-statistic for AR (`method')"
    label var p_ar_`method' "P-value for AR (`method')"
    label var sig_ar_`method' "Significant AR at 5% (`method')"
}

/*------------------------------------------------------------------------------
9. Save Abnormal Returns Dataset
------------------------------------------------------------------------------*/

display as text _newline "9. Saving abnormal returns dataset..."

// Sort and save
sort event_id event_day
compress
save "${processed}/abnormal_returns.dta", replace

display as text "Abnormal returns dataset saved: `c(N)' event-day observations"

/*------------------------------------------------------------------------------
10. Summary Statistics
------------------------------------------------------------------------------*/

display as text _newline "10. Generating summary statistics..."

// Summary statistics for abnormal returns
preserve
    keep if announcement_day == 1
    
    summarize ar_market_model ar_market_adjusted ar_mean_adjusted
    summarize car_1_market_model car_3_market_model car_5_market_model car_10_market_model
    
    // Export summary statistics
    estpost summarize ar_market_model ar_market_adjusted ar_mean_adjusted ///
                      car_1_market_model car_3_market_model car_5_market_model car_10_market_model
    esttab using "${summary}/abnormal_returns_summary.csv", ///
        cells("mean(fmt(4)) sd(fmt(4)) min(fmt(4)) max(fmt(4)) count(fmt(0))") ///
        replace noobs nonumber
restore

display as text _newline "=== Return Calculations Complete ==="
display as text "Output files created:"
display as text "- ${processed}/abnormal_returns.dta"
display as text "- ${summary}/abnormal_returns_summary.csv"
display as text _newline "Next step: Run 04_create_variables.do"
