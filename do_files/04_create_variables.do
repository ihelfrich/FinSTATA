/*==============================================================================
Comprehensive Event Study Toolkit: Variable Creation and Labeling
================================================================================

Purpose: Create derived variables, financial ratios, and additional controls
         for the event study analysis based on the actual dataset structure.
         Adapts to the covidevent.dta format with company_id, event_date, 
         tan, total_assets, crossborder, dv, and deal_value.

Author: Comprehensive Event Study Toolkit
Date: Created for academic and professional event study analysis

Input Files:
- data/processed/abnormal_returns.dta

Output Files:
- data/processed/event_study_final.dta

Notes:
- Creates financial ratios and performance measures from available data
- Handles missing data and outliers appropriately
- Adds deal characteristics and time controls
- Prepares variables for regression analysis

==============================================================================*/

// Ensure setup has been run
if "${main_dir}" == "" {
    display as error "Please run 00_setup.do first"
    exit
}

display as text _newline "=== Variable Creation and Labeling ==="
display as text "Creating derived variables and financial ratios..."

/*------------------------------------------------------------------------------
1. Load Abnormal Returns Dataset
------------------------------------------------------------------------------*/

display as text _newline "1. Loading abnormal returns dataset..."

use "${processed}/abnormal_returns.dta", clear

display as text "Abnormal returns dataset loaded: `c(N)' observations"

/*------------------------------------------------------------------------------
2. Create Financial Ratios from Available Data
------------------------------------------------------------------------------*/

display as text _newline "2. Creating financial ratios from available data..."

// Tangible asset ratio (tan/total_assets)
gen tangible_ratio = tan / total_assets if !missing(tan) & !missing(total_assets) & total_assets > 0
label var tangible_ratio "Tangible Assets / Total Assets"

// Log of total assets (size measure)
gen log_assets = ln(total_assets) if !missing(total_assets) & total_assets > 0
label var log_assets "Log of Total Assets"

// Asset efficiency (dv/total_assets)
gen asset_efficiency = dv / total_assets if !missing(dv) & !missing(total_assets) & total_assets > 0
label var asset_efficiency "Deal Value / Total Assets"

// Return on assets proxy (using available data)
gen roa_proxy = dv / total_assets if !missing(dv) & !missing(total_assets) & total_assets > 0
label var roa_proxy "ROA Proxy (DV / Total Assets)"

/*------------------------------------------------------------------------------
3. Create Deal-Specific Variables
------------------------------------------------------------------------------*/

display as text _newline "3. Creating deal-specific variables..."

// Log of deal value
gen log_deal_value = ln(deal_value) if !missing(deal_value) & deal_value > 0
label var log_deal_value "Log of Deal Value"

// Relative deal size
gen relative_deal_size = deal_value / total_assets if !missing(deal_value) & !missing(total_assets) & total_assets > 0
label var relative_deal_size "Relative Deal Size (Deal Value / Total Assets)"

// Deal size categories (in millions)
gen large_deal = (deal_value >= 1000000000) if !missing(deal_value)
gen medium_deal = (deal_value >= 100000000 & deal_value < 1000000000) if !missing(deal_value)
gen small_deal = (deal_value < 100000000) if !missing(deal_value)

label var large_deal "Large Deal (≥$1B)"
label var medium_deal "Medium Deal ($100M-$1B)"
label var small_deal "Small Deal (<$100M)"

// Cross-border deal indicator (already exists)
label var crossborder "Cross-border Deal"

/*------------------------------------------------------------------------------
4. Create Size and Performance Categories
------------------------------------------------------------------------------*/

display as text _newline "4. Creating size and performance categories..."

// Large firm indicator (top quartile by assets)
egen p75_assets = pctile(total_assets), p(75)
gen large_firm = (total_assets > p75_assets & !missing(total_assets))
label var large_firm "Large Firm (Top Quartile by Assets)"

// High tangible assets firm
egen p75_tangible = pctile(tangible_ratio), p(75)
gen high_tangible = (tangible_ratio > p75_tangible & !missing(tangible_ratio))
label var high_tangible "High Tangible Assets Firm"

// High efficiency firm
egen p75_efficiency = pctile(asset_efficiency), p(75)
gen high_efficiency = (asset_efficiency > p75_efficiency & !missing(asset_efficiency))
label var high_efficiency "High Asset Efficiency Firm"

/*------------------------------------------------------------------------------
5. Create Time and Event Variables
------------------------------------------------------------------------------*/

display as text _newline "5. Creating time and event variables..."

// Event timing variables
gen event_year = year(event_date)
gen event_month = month(event_date)
gen event_quarter = quarter(event_date)

label var event_year "Event Year"
label var event_month "Event Month"
label var event_quarter "Event Quarter"

// COVID-19 period indicator (2020 onwards)
gen covid_period = (event_year >= 2020)
label var covid_period "COVID-19 Period (2020+)"

// Early COVID period (2020)
gen early_covid = (event_year == 2020)
label var early_covid "Early COVID Period (2020)"

// Late COVID period (2021+)
gen late_covid = (event_year >= 2021)
label var late_covid "Late COVID Period (2021+)"

/*------------------------------------------------------------------------------
6. Create Market Condition Variables
------------------------------------------------------------------------------*/

display as text _newline "6. Creating market condition variables..."

// Average market conditions by month
preserve
    keep if announcement_day == 1
    collapse (mean) avg_market_return = vw_market_return, by(event_year event_month)
    rename avg_market_return market_conditions
    tempfile market_conditions
    save `market_conditions'
restore

merge m:1 event_year event_month using `market_conditions', keep(match master) nogen
label var market_conditions "Average Market Return in Event Month"

// Market volatility by month
preserve
    keep if announcement_day == 1
    collapse (sd) market_volatility = vw_market_return, by(event_year event_month)
    tempfile market_vol
    save `market_vol'
restore

merge m:1 event_year event_month using `market_vol', keep(match master) nogen
label var market_volatility "Market Volatility in Event Month"

/*------------------------------------------------------------------------------
7. Create Interaction Terms
------------------------------------------------------------------------------*/

display as text _newline "7. Creating interaction terms for analysis..."

// Size-performance interactions
gen size_efficiency = log_assets * asset_efficiency if !missing(log_assets) & !missing(asset_efficiency)
gen size_tangible = log_assets * tangible_ratio if !missing(log_assets) & !missing(tangible_ratio)

label var size_efficiency "Size × Efficiency Interaction"
label var size_tangible "Size × Tangible Assets Interaction"

// COVID period interactions
gen covid_size = covid_period * log_assets if !missing(log_assets)
gen covid_crossborder = covid_period * crossborder
gen covid_efficiency = covid_period * asset_efficiency if !missing(asset_efficiency)

label var covid_size "COVID × Size Interaction"
label var covid_crossborder "COVID × Cross-border Interaction"
label var covid_efficiency "COVID × Efficiency Interaction"

// Deal size interactions
gen large_deal_covid = large_deal * covid_period
gen crossborder_large = crossborder * large_deal

label var large_deal_covid "Large Deal × COVID Interaction"
label var crossborder_large "Cross-border × Large Deal Interaction"

/*------------------------------------------------------------------------------
8. Handle Missing Data and Winsorize Variables
------------------------------------------------------------------------------*/

display as text _newline "8. Handling missing data and winsorizing variables..."

// Winsorize continuous variables to reduce outlier impact
local winsor_vars "tangible_ratio asset_efficiency log_assets log_deal_value relative_deal_size"

foreach var of local winsor_vars {
    capture confirm variable `var'
    if _rc == 0 {
        capture winsor2 `var', replace cuts(1 99)
        if _rc != 0 {
            display as text "Warning: Could not winsorize `var'"
        }
    }
}

/*------------------------------------------------------------------------------
9. Create Summary Variables and Indicators
------------------------------------------------------------------------------*/

display as text _newline "9. Creating summary variables and indicators..."

// Financially healthy indicator (high tangible assets, low relative deal size)
gen financially_healthy = (tangible_ratio > 0.5 & relative_deal_size < 2 & !missing(tangible_ratio) & !missing(relative_deal_size))
label var financially_healthy "Financially Healthy Firm Indicator"

// High efficiency indicator
gen high_efficiency_firm = (asset_efficiency > 0.1 & !missing(asset_efficiency))
label var high_efficiency_firm "High Efficiency Firm Indicator"

/*------------------------------------------------------------------------------
10. Data Quality Checks
------------------------------------------------------------------------------*/

display as text _newline "10. Performing data quality checks..."

// Check for extreme values
foreach var of varlist tangible_ratio asset_efficiency relative_deal_size {
    capture confirm variable `var'
    if _rc == 0 {
        count if `var' < -5 | `var' > 5
        if r(N) > 0 {
            display as text "Warning: `r(N)' extreme values in `var'"
        }
    }
}

// Check for missing key variables
local key_vars "firm_id event_date"
foreach var of local key_vars {
    count if missing(`var')
    if r(N) > 0 {
        display as text "Warning: `r(N)' missing values in `var'"
    }
}

/*------------------------------------------------------------------------------
11. Final Dataset Preparation
------------------------------------------------------------------------------*/

display as text _newline "11. Preparing final dataset..."

// Create analysis sample indicator
gen analysis_sample = (!missing(event_date) & !missing(firm_id))
label var analysis_sample "Included in Analysis Sample"

// Sort and save
sort event_id event_day
compress
save "${processed}/event_study_final.dta", replace

display as text "Final event study dataset saved: `c(N)' observations"

/*------------------------------------------------------------------------------
12. Summary Statistics
------------------------------------------------------------------------------*/

display as text _newline "12. Generating comprehensive summary statistics..."

// Summary statistics for key variables
preserve
    keep if announcement_day == 1 & analysis_sample == 1
    
    local summary_vars "tangible_ratio asset_efficiency log_assets log_deal_value relative_deal_size"
    local summary_vars "`summary_vars' large_firm high_tangible high_efficiency crossborder covid_period"
    
    summarize `summary_vars'
    
    // Export summary statistics
    estpost summarize `summary_vars'
    esttab using "${summary}/final_variables_summary.csv", ///
        cells("mean(fmt(4)) sd(fmt(4)) min(fmt(4)) max(fmt(4)) count(fmt(0))") ///
        replace noobs nonumber
    
    // Correlation matrix for key variables
    correlate tangible_ratio asset_efficiency log_assets relative_deal_size crossborder
    
    // Export correlation matrix
    estpost correlate tangible_ratio asset_efficiency log_assets relative_deal_size crossborder, matrix
    esttab using "${summary}/correlation_matrix.csv", ///
        replace noobs nonumber unstack not
restore

display as text _newline "=== Variable Creation Complete ==="
display as text "Output files created:"
display as text "- ${processed}/event_study_final.dta"
display as text "- ${summary}/final_variables_summary.csv"
display as text "- ${summary}/correlation_matrix.csv"
display as text _newline "Next step: Run 05_run_analysis.do"
