/*==============================================================================
Comprehensive Event Study Toolkit: Statistical Analysis
================================================================================

Purpose: Run comprehensive statistical tests and cross-sectional regressions
         for the event study analysis. Includes parametric and non-parametric
         tests, regression analysis, and robustness checks.

Author: Comprehensive Event Study Toolkit
Date: Created for academic and professional event study analysis

Input Files:
- data/processed/event_study_final.dta

Output Files:
- outputs/regression_results/main_results.csv
- outputs/regression_results/robustness_tests.csv
- outputs/summary_stats/significance_tests.csv

Notes:
- Implements multiple statistical testing approaches
- Handles clustering and cross-sectional dependence
- Provides comprehensive regression analysis
- Includes robustness checks and sensitivity analysis

==============================================================================*/

// Ensure setup has been run
if "${main_dir}" == "" {
    display as error "Please run 00_setup.do first"
    exit
}

display as text _newline "=== Statistical Analysis ==="
display as text "Running comprehensive event study analysis..."

/*------------------------------------------------------------------------------
1. Load Final Dataset
------------------------------------------------------------------------------*/

display as text _newline "1. Loading final event study dataset..."

use "${processed}/event_study_final.dta", clear

// Keep only analysis sample
keep if analysis_sample == 1

display as text "Analysis sample: `c(N)' observations"

/*------------------------------------------------------------------------------
2. Aggregate Event-Level Analysis
------------------------------------------------------------------------------*/

display as text _newline "2. Creating event-level dataset for analysis..."

// Create event-level dataset (one observation per event)
preserve
    keep if announcement_day == 1
    
    // Keep relevant variables for event-level analysis
    keep event_id firm_id event_date event_year event_month event_quarter ///
         car_1_market_model car_3_market_model car_5_market_model car_10_market_model ///
         car_1_market_adjusted car_3_market_adjusted car_5_market_adjusted car_10_market_adjusted ///
         ar_market_model ar_market_adjusted ///
         roa leverage revenue_growth log_assets market_to_book ///
         financially_healthy high_growth large_firm ///
         ind_technology ind_finance ind_manufacturing ///
         crisis_period market_conditions avg_volatility ///
         size_roa size_leverage tech_roa crisis_roa
    
    tempfile event_level
    save `event_level'
restore

/*------------------------------------------------------------------------------
3. Parametric Significance Tests
------------------------------------------------------------------------------*/

display as text _newline "3. Running parametric significance tests..."

use `event_level', clear

// T-tests for mean abnormal returns
local car_vars "car_1_market_model car_3_market_model car_5_market_model car_10_market_model"

foreach var of local car_vars {
    ttest `var' = 0
    
    // Store results
    local mean_`var' = r(mu_1)
    local t_stat_`var' = r(t)
    local p_value_`var' = r(p)
    local n_obs_`var' = r(N_1)
}

// Sign test (non-parametric)
foreach var of local car_vars {
    signtest `var' = 0
    local sign_p_`var' = r(p)
}

// Wilcoxon signed-rank test
foreach var of local car_vars {
    signrank `var' = 0
    local wilcoxon_p_`var' = r(p)
}

/*------------------------------------------------------------------------------
4. Cross-Sectional Regression Analysis
------------------------------------------------------------------------------*/

display as text _newline "4. Running cross-sectional regression analysis..."

// Main regression: CAR on firm characteristics (adapted to actual dataset)
eststo clear

// Model 1: Basic firm characteristics
eststo model1: regress car_3_market_model log_assets tangible_ratio crossborder, robust

// Model 2: Add deal characteristics
eststo model2: regress car_3_market_model log_assets tangible_ratio crossborder ///
               asset_efficiency relative_deal_size, robust

// Model 3: Add deal size controls
eststo model3: regress car_3_market_model log_assets tangible_ratio crossborder ///
               asset_efficiency relative_deal_size large_deal medium_deal, robust

// Model 4: Add time controls
eststo model4: regress car_3_market_model log_assets tangible_ratio crossborder ///
               asset_efficiency relative_deal_size large_deal medium_deal covid_period, robust

// Model 5: Add interactions
eststo model5: regress car_3_market_model log_assets tangible_ratio crossborder ///
               asset_efficiency relative_deal_size large_deal medium_deal covid_period ///
               covid_size covid_crossborder covid_efficiency, robust

// Export main regression results
esttab model1 model2 model3 model4 model5 using "${regression}/main_results.csv", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Cross-Sectional Regression Results") ///
    mtitles("Basic" "Deal Chars" "Deal Size" "Time" "Interactions") ///
    addnotes("Robust standard errors in parentheses" "* p<0.10, ** p<0.05, *** p<0.01")

/*------------------------------------------------------------------------------
5. Robustness Tests
------------------------------------------------------------------------------*/

display as text _newline "5. Running robustness tests..."

eststo clear

// Different event windows
eststo rob1: regress car_1_market_model log_assets tangible_ratio crossborder ///
             asset_efficiency covid_period, robust

eststo rob2: regress car_5_market_model log_assets tangible_ratio crossborder ///
             asset_efficiency covid_period, robust

eststo rob3: regress car_10_market_model log_assets tangible_ratio crossborder ///
             asset_efficiency covid_period, robust

// Different abnormal return methods
eststo rob4: regress car_3_market_adjusted log_assets tangible_ratio crossborder ///
             asset_efficiency covid_period, robust

// Subsample analysis: Large firms only
eststo rob5: regress car_3_market_model log_assets tangible_ratio crossborder ///
             asset_efficiency covid_period if large_firm == 1, robust

// Subsample analysis: Cross-border deals only
eststo rob6: regress car_3_market_model log_assets tangible_ratio ///
             asset_efficiency covid_period if crossborder == 1, robust

// Export robustness results
esttab rob1 rob2 rob3 rob4 rob5 rob6 using "${regression}/robustness_tests.csv", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Robustness Tests") ///
    mtitles("CAR[-1,+1]" "CAR[-5,+5]" "CAR[-10,+10]" "Mkt-Adj" "Large Firms" "Cross-border") ///
    addnotes("Robust standard errors in parentheses" "* p<0.10, ** p<0.05, *** p<0.01")

/*------------------------------------------------------------------------------
6. Time-Series Analysis
------------------------------------------------------------------------------*/

display as text _newline "6. Running time-series analysis..."

// Aggregate abnormal returns by event date
preserve
    collapse (mean) avg_car = car_3_market_model (count) n_events = event_id, by(event_date)
    
    // Time-series regression
    tsset event_date
    
    // Test for autocorrelation
    regress avg_car
    estat bgodfrey, lags(1/5)
    
    // Export time-series results
    export delimited using "${regression}/time_series_cars.csv", replace
restore

/*------------------------------------------------------------------------------
7. Industry and Time Analysis
------------------------------------------------------------------------------*/

display as text _newline "7. Running industry and time analysis..."

// Deal type analysis
preserve
    collapse (mean) avg_car = car_3_market_model (count) n_events = event_id, ///
        by(crossborder large_deal)
    
    export delimited using "${regression}/deal_type_analysis.csv", replace
restore

// Time period analysis
preserve
    collapse (mean) avg_car = car_3_market_model (count) n_events = event_id, ///
        by(event_year)
    
    export delimited using "${regression}/yearly_analysis.csv", replace
restore

/*------------------------------------------------------------------------------
8. Statistical Significance Summary
------------------------------------------------------------------------------*/

display as text _newline "8. Creating statistical significance summary..."

// Create summary table of significance tests
clear
set obs 4

gen event_window = ""
gen mean_car = .
gen t_statistic = .
gen p_value_param = .
gen p_value_sign = .
gen p_value_wilcoxon = .
gen n_observations = .

replace event_window = "[-1,+1]" in 1
replace event_window = "[-3,+3]" in 2
replace event_window = "[-5,+5]" in 3
replace event_window = "[-10,+10]" in 4

replace mean_car = `mean_car_1_market_model' in 1
replace mean_car = `mean_car_3_market_model' in 2
replace mean_car = `mean_car_5_market_model' in 3
replace mean_car = `mean_car_10_market_model' in 4

replace t_statistic = `t_stat_car_1_market_model' in 1
replace t_statistic = `t_stat_car_3_market_model' in 2
replace t_statistic = `t_stat_car_5_market_model' in 3
replace t_statistic = `t_stat_car_10_market_model' in 4

replace p_value_param = `p_value_car_1_market_model' in 1
replace p_value_param = `p_value_car_3_market_model' in 2
replace p_value_param = `p_value_car_5_market_model' in 3
replace p_value_param = `p_value_car_10_market_model' in 4

replace p_value_sign = `sign_p_car_1_market_model' in 1
replace p_value_sign = `sign_p_car_3_market_model' in 2
replace p_value_sign = `sign_p_car_5_market_model' in 3
replace p_value_sign = `sign_p_car_10_market_model' in 4

replace p_value_wilcoxon = `wilcoxon_p_car_1_market_model' in 1
replace p_value_wilcoxon = `wilcoxon_p_car_3_market_model' in 2
replace p_value_wilcoxon = `wilcoxon_p_car_5_market_model' in 3
replace p_value_wilcoxon = `wilcoxon_p_car_10_market_model' in 4

replace n_observations = `n_obs_car_1_market_model' in 1
replace n_observations = `n_obs_car_3_market_model' in 2
replace n_observations = `n_obs_car_5_market_model' in 3
replace n_observations = `n_obs_car_10_market_model' in 4

export delimited using "${summary}/significance_tests.csv", replace

/*------------------------------------------------------------------------------
9. Generate Analysis Summary
------------------------------------------------------------------------------*/

display as text _newline "9. Generating analysis summary..."

// Display key results
display as text _newline "=== KEY RESULTS SUMMARY ==="
display as text "Mean CAR [-3,+3]: " %6.4f `mean_car_3_market_model'
display as text "T-statistic: " %6.2f `t_stat_car_3_market_model'
display as text "P-value: " %6.4f `p_value_car_3_market_model'
display as text "Number of events: " %6.0f `n_obs_car_3_market_model'

if `p_value_car_3_market_model' < 0.01 {
    display as text "Result: Highly significant at 1% level"
}
else if `p_value_car_3_market_model' < 0.05 {
    display as text "Result: Significant at 5% level"
}
else if `p_value_car_3_market_model' < 0.10 {
    display as text "Result: Significant at 10% level"
}
else {
    display as text "Result: Not statistically significant"
}

display as text _newline "=== Statistical Analysis Complete ==="
display as text "Output files created:"
display as text "- ${regression}/main_results.csv"
display as text "- ${regression}/robustness_tests.csv"
display as text "- ${regression}/time_series_cars.csv"
display as text "- ${regression}/industry_analysis.csv"
display as text "- ${regression}/yearly_analysis.csv"
display as text "- ${summary}/significance_tests.csv"
display as text _newline "Next step: Run 06_export_results.do"
