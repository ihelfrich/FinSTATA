/*==============================================================================
COVID-19 Event Study Template
================================================================================

Purpose: Template for analyzing COVID-19 related corporate events using the
         comprehensive event study toolkit. This template demonstrates how to
         use the toolkit for pandemic-related event studies.

Author: Comprehensive Event Study Toolkit
Date: Created for COVID-19 event study analysis

Notes:
- This template uses the covidevent.dta dataset structure
- Focuses on COVID-19 period effects and cross-border deals
- Demonstrates time-varying effects during the pandemic

==============================================================================*/

clear all
set more off

// Set working directory (modify as needed)
cd "path/to/your/event-study-toolkit"

/*------------------------------------------------------------------------------
1. Setup and Configuration
------------------------------------------------------------------------------*/

// Run setup script
do "do_files/00_setup.do"

// Set COVID-specific parameters
global covid_start_date = date("2020-01-01", "YMD")
global covid_announcement_date = date("2020-03-11", "YMD")  // WHO pandemic declaration

/*------------------------------------------------------------------------------
2. Data Import and Preparation
------------------------------------------------------------------------------*/

// Import COVID event data
do "do_files/01_import_data.do"

// Define event windows around COVID events
do "do_files/02_define_events.do"

// Calculate abnormal returns
do "do_files/03_calculate_returns.do"

/*------------------------------------------------------------------------------
3. COVID-Specific Variable Creation
------------------------------------------------------------------------------*/

// Load the dataset for COVID-specific modifications
use "${processed}/abnormal_returns.dta", clear

// Create COVID-specific time periods
gen pre_covid = (event_date < ${covid_start_date})
gen early_covid = (event_date >= ${covid_start_date} & event_date < date("2020-06-01", "YMD"))
gen mid_covid = (event_date >= date("2020-06-01", "YMD") & event_date < date("2021-01-01", "YMD"))
gen late_covid = (event_date >= date("2021-01-01", "YMD"))

label var pre_covid "Pre-COVID period (before 2020)"
label var early_covid "Early COVID period (Jan-May 2020)"
label var mid_covid "Mid COVID period (Jun-Dec 2020)"
label var late_covid "Late COVID period (2021+)"

// Create COVID severity measures
gen covid_severity = 1 if early_covid == 1
replace covid_severity = 2 if mid_covid == 1
replace covid_severity = 3 if late_covid == 1
replace covid_severity = 0 if pre_covid == 1

label var covid_severity "COVID period severity (0=pre, 1=early, 2=mid, 3=late)"

// Save modified dataset
save "${processed}/covid_abnormal_returns.dta", replace

/*------------------------------------------------------------------------------
4. Create COVID-Specific Variables
------------------------------------------------------------------------------*/

// Run standard variable creation with COVID modifications
do "do_files/04_create_variables.do"

// Load final dataset for additional COVID variables
use "${processed}/event_study_final.dta", clear

// Create additional COVID-specific interactions
gen crossborder_early_covid = crossborder * early_covid
gen crossborder_mid_covid = crossborder * mid_covid
gen crossborder_late_covid = crossborder * late_covid

gen large_deal_early_covid = large_deal * early_covid
gen large_deal_mid_covid = large_deal * mid_covid
gen large_deal_late_covid = large_deal * late_covid

label var crossborder_early_covid "Cross-border × Early COVID"
label var crossborder_mid_covid "Cross-border × Mid COVID"
label var crossborder_late_covid "Cross-border × Late COVID"
label var large_deal_early_covid "Large Deal × Early COVID"
label var large_deal_mid_covid "Large Deal × Mid COVID"
label var large_deal_late_covid "Large Deal × Late COVID"

// Save COVID-enhanced dataset
save "${processed}/covid_event_study_final.dta", replace

/*------------------------------------------------------------------------------
5. COVID-Specific Analysis
------------------------------------------------------------------------------*/

// Keep only announcement day observations for analysis
keep if announcement_day == 1 & analysis_sample == 1

// COVID Period Analysis
display as text _newline "=== COVID PERIOD ANALYSIS ==="

// Test for differences across COVID periods
eststo clear

// Model 1: Basic COVID period effects
eststo covid1: regress car_3_market_model early_covid mid_covid late_covid, robust

// Model 2: Add firm characteristics
eststo covid2: regress car_3_market_model early_covid mid_covid late_covid ///
               log_assets tangible_ratio crossborder, robust

// Model 3: Add deal characteristics
eststo covid3: regress car_3_market_model early_covid mid_covid late_covid ///
               log_assets tangible_ratio crossborder asset_efficiency large_deal, robust

// Model 4: Add interactions
eststo covid4: regress car_3_market_model early_covid mid_covid late_covid ///
               log_assets tangible_ratio crossborder asset_efficiency large_deal ///
               crossborder_early_covid crossborder_mid_covid crossborder_late_covid, robust

// Export COVID analysis results
esttab covid1 covid2 covid3 covid4 using "${regression}/covid_analysis.csv", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("COVID-19 Period Analysis") ///
    mtitles("Basic" "Firm Chars" "Deal Chars" "Interactions") ///
    addnotes("Robust standard errors in parentheses" "* p<0.10, ** p<0.05, *** p<0.01")

/*------------------------------------------------------------------------------
6. Cross-Border Deal Analysis During COVID
------------------------------------------------------------------------------*/

display as text _newline "=== CROSS-BORDER DEAL ANALYSIS ==="

eststo clear

// Cross-border effects by COVID period
eststo cb1: regress car_3_market_model crossborder if pre_covid == 1, robust
eststo cb2: regress car_3_market_model crossborder if early_covid == 1, robust
eststo cb3: regress car_3_market_model crossborder if mid_covid == 1, robust
eststo cb4: regress car_3_market_model crossborder if late_covid == 1, robust

// Export cross-border analysis
esttab cb1 cb2 cb3 cb4 using "${regression}/crossborder_covid_analysis.csv", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Cross-Border Effects by COVID Period") ///
    mtitles("Pre-COVID" "Early COVID" "Mid COVID" "Late COVID") ///
    addnotes("Robust standard errors in parentheses" "* p<0.10, ** p<0.05, *** p<0.01")

/*------------------------------------------------------------------------------
7. Time Series Analysis of COVID Effects
------------------------------------------------------------------------------*/

display as text _newline "=== TIME SERIES ANALYSIS ==="

// Monthly analysis of COVID effects
preserve
    collapse (mean) avg_car = car_3_market_model ///
             (mean) avg_crossborder = crossborder ///
             (count) n_events = event_id, ///
             by(event_year event_month)
    
    // Create time variable
    gen time = ym(event_year, event_month)
    format time %tm
    
    // Time series analysis
    tsset time
    
    // Plot time series
    line avg_car time, title("Average CAR Over Time During COVID") ///
        xtitle("Time") ytitle("Average CAR [-3,+3]") ///
        xline(`=ym(2020,3)', lpattern(dash) lcolor(red)) ///
        note("Red line indicates WHO pandemic declaration (March 2020)")
    
    graph export "${outputs}/plots/covid_car_timeseries.png", replace
    
    // Export time series data
    export delimited using "${regression}/covid_timeseries.csv", replace
restore

/*------------------------------------------------------------------------------
8. Summary and Interpretation
------------------------------------------------------------------------------*/

display as text _newline "=== COVID EVENT STUDY SUMMARY ==="

// Calculate key statistics
summarize car_3_market_model if pre_covid == 1
local pre_covid_car = r(mean)

summarize car_3_market_model if early_covid == 1
local early_covid_car = r(mean)

summarize car_3_market_model if mid_covid == 1
local mid_covid_car = r(mean)

summarize car_3_market_model if late_covid == 1
local late_covid_car = r(mean)

// Display results
display as text "Average CAR [-3,+3] by period:"
display as text "Pre-COVID: " %6.4f `pre_covid_car'
display as text "Early COVID: " %6.4f `early_covid_car'
display as text "Mid COVID: " %6.4f `mid_covid_car'
display as text "Late COVID: " %6.4f `late_covid_car'

// Test for significant differences
ttest car_3_market_model if pre_covid == 1 | early_covid == 1, by(early_covid)
local p_pre_early = r(p)

ttest car_3_market_model if early_covid == 1 | late_covid == 1, by(late_covid)
local p_early_late = r(p)

display as text _newline "Statistical significance:"
display as text "Pre-COVID vs Early COVID p-value: " %6.4f `p_pre_early'
display as text "Early COVID vs Late COVID p-value: " %6.4f `p_early_late'

/*------------------------------------------------------------------------------
9. Export Results
------------------------------------------------------------------------------*/

// Run standard export script
do "do_files/06_export_results.do"

display as text _newline "=== COVID EVENT STUDY TEMPLATE COMPLETE ==="
display as text "COVID-specific analysis files created:"
display as text "- ${regression}/covid_analysis.csv"
display as text "- ${regression}/crossborder_covid_analysis.csv"
display as text "- ${regression}/covid_timeseries.csv"
display as text "- ${outputs}/plots/covid_car_timeseries.png"
