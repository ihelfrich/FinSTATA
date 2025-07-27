/*==============================================================================
M&A Event Study Template
================================================================================

Purpose: Template for analyzing merger and acquisition events using the
         comprehensive event study toolkit. Demonstrates how to adapt the
         toolkit for M&A-specific analysis.

Author: Comprehensive Event Study Toolkit
Date: Created for M&A event study analysis

Notes:
- This template can be adapted for traditional M&A datasets
- Focuses on deal characteristics and firm-specific factors
- Demonstrates cross-sectional regression analysis

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

// Set M&A-specific parameters
global min_deal_value = 10000000  // Minimum deal value ($10M)
global max_relative_size = 5      // Maximum relative deal size (500%)

/*------------------------------------------------------------------------------
2. Data Import and Preparation
------------------------------------------------------------------------------*/

// Import M&A event data
do "do_files/01_import_data.do"

// Define event windows around M&A announcements
do "do_files/02_define_events.do"

// Calculate abnormal returns
do "do_files/03_calculate_returns.do"

/*------------------------------------------------------------------------------
3. M&A-Specific Variable Creation
------------------------------------------------------------------------------*/

// Load the dataset for M&A-specific modifications
use "${processed}/abnormal_returns.dta", clear

// Create M&A-specific variables
gen mega_deal = (deal_value >= 1000000000) if !missing(deal_value)  // $1B+ deals
gen transformative_deal = (relative_deal_size >= 0.5) if !missing(relative_deal_size)  // 50%+ of firm value

label var mega_deal "Mega Deal (≥$1B)"
label var transformative_deal "Transformative Deal (≥50% of firm value)"

// Create deal premium measures (if available)
capture confirm variable deal_premium
if _rc == 0 {
    gen high_premium = (deal_premium > 0.3) if !missing(deal_premium)
    label var high_premium "High Premium Deal (>30%)"
}

// Save M&A-enhanced dataset
save "${processed}/ma_abnormal_returns.dta", replace

/*------------------------------------------------------------------------------
4. Create M&A-Specific Variables
------------------------------------------------------------------------------*/

// Run standard variable creation
do "do_files/04_create_variables.do"

// Load final dataset for additional M&A variables
use "${processed}/event_study_final.dta", clear

// Create M&A-specific interactions
gen crossborder_mega = crossborder * mega_deal
gen large_firm_mega = large_firm * mega_deal

label var crossborder_mega "Cross-border × Mega Deal"
label var large_firm_mega "Large Firm × Mega Deal"

// Create target characteristics (if this is target-focused analysis)
gen target_efficiency = asset_efficiency  // Rename for clarity in M&A context
label var target_efficiency "Target Firm Efficiency"

// Save M&A-enhanced dataset
save "${processed}/ma_event_study_final.dta", replace

/*------------------------------------------------------------------------------
5. M&A-Specific Analysis
------------------------------------------------------------------------------*/

// Keep only announcement day observations for analysis
keep if announcement_day == 1 & analysis_sample == 1

// M&A Deal Characteristics Analysis
display as text _newline "=== M&A DEAL CHARACTERISTICS ANALYSIS ==="

eststo clear

// Model 1: Basic deal characteristics
eststo ma1: regress car_3_market_model log_deal_value crossborder, robust

// Model 2: Add target characteristics
eststo ma2: regress car_3_market_model log_deal_value crossborder ///
            log_assets tangible_ratio target_efficiency, robust

// Model 3: Add deal size effects
eststo ma3: regress car_3_market_model log_deal_value crossborder ///
            log_assets tangible_ratio target_efficiency ///
            mega_deal transformative_deal, robust

// Model 4: Add interactions
eststo ma4: regress car_3_market_model log_deal_value crossborder ///
            log_assets tangible_ratio target_efficiency ///
            mega_deal transformative_deal ///
            crossborder_mega large_firm_mega, robust

// Export M&A analysis results
esttab ma1 ma2 ma3 ma4 using "${regression}/ma_analysis.csv", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("M&A Event Study Analysis") ///
    mtitles("Basic" "Target Chars" "Deal Size" "Interactions") ///
    addnotes("Robust standard errors in parentheses" "* p<0.10, ** p<0.05, *** p<0.01")

/*------------------------------------------------------------------------------
6. Deal Size Analysis
------------------------------------------------------------------------------*/

display as text _newline "=== DEAL SIZE ANALYSIS ==="

eststo clear

// Analysis by deal size categories
eststo size1: regress car_3_market_model log_assets tangible_ratio crossborder if small_deal == 1, robust
eststo size2: regress car_3_market_model log_assets tangible_ratio crossborder if medium_deal == 1, robust
eststo size3: regress car_3_market_model log_assets tangible_ratio crossborder if large_deal == 1, robust

// Export deal size analysis
esttab size1 size2 size3 using "${regression}/deal_size_analysis.csv", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Analysis by Deal Size") ///
    mtitles("Small Deals" "Medium Deals" "Large Deals") ///
    addnotes("Robust standard errors in parentheses" "* p<0.10, ** p<0.05, *** p<0.01")

/*------------------------------------------------------------------------------
7. Cross-Border vs Domestic Deal Analysis
------------------------------------------------------------------------------*/

display as text _newline "=== CROSS-BORDER VS DOMESTIC ANALYSIS ==="

// Compare cross-border and domestic deals
ttest car_3_market_model, by(crossborder)
local cb_p_value = r(p)

// Summary statistics by deal type
tabstat car_3_market_model log_assets deal_value, by(crossborder) statistics(mean sd count)

// Regression analysis
eststo clear
eststo domestic: regress car_3_market_model log_assets tangible_ratio target_efficiency if crossborder == 0, robust
eststo crossborder: regress car_3_market_model log_assets tangible_ratio target_efficiency if crossborder == 1, robust

esttab domestic crossborder using "${regression}/domestic_vs_crossborder.csv", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Domestic vs Cross-Border Deals") ///
    mtitles("Domestic" "Cross-Border") ///
    addnotes("Robust standard errors in parentheses" "* p<0.10, ** p<0.05, *** p<0.01")

/*------------------------------------------------------------------------------
8. Target Firm Characteristics Analysis
------------------------------------------------------------------------------*/

display as text _newline "=== TARGET FIRM CHARACTERISTICS ==="

// Create target firm performance categories
egen p25_efficiency = pctile(target_efficiency), p(25)
egen p75_efficiency = pctile(target_efficiency), p(75)

gen low_efficiency_target = (target_efficiency <= p25_efficiency) if !missing(target_efficiency)
gen high_efficiency_target = (target_efficiency >= p75_efficiency) if !missing(target_efficiency)

// Analysis by target efficiency
eststo clear
eststo low_eff: regress car_3_market_model log_assets crossborder if low_efficiency_target == 1, robust
eststo high_eff: regress car_3_market_model log_assets crossborder if high_efficiency_target == 1, robust

esttab low_eff high_eff using "${regression}/target_efficiency_analysis.csv", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Analysis by Target Efficiency") ///
    mtitles("Low Efficiency" "High Efficiency") ///
    addnotes("Robust standard errors in parentheses" "* p<0.10, ** p<0.05, *** p<0.01")

/*------------------------------------------------------------------------------
9. Time Trend Analysis
------------------------------------------------------------------------------*/

display as text _newline "=== TIME TREND ANALYSIS ==="

// Annual analysis
preserve
    collapse (mean) avg_car = car_3_market_model ///
             (mean) avg_deal_value = deal_value ///
             (mean) pct_crossborder = crossborder ///
             (count) n_deals = event_id, ///
             by(event_year)
    
    // Plot time trends
    line avg_car event_year, title("Average M&A Announcement Returns by Year") ///
        xtitle("Year") ytitle("Average CAR [-3,+3]")
    graph export "${outputs}/plots/ma_car_by_year.png", replace
    
    // Export annual data
    export delimited using "${regression}/ma_annual_trends.csv", replace
restore

/*------------------------------------------------------------------------------
10. Summary and Key Findings
------------------------------------------------------------------------------*/

display as text _newline "=== M&A EVENT STUDY SUMMARY ==="

// Calculate key statistics
count
local total_deals = r(N)

count if crossborder == 1
local cb_deals = r(N)
local cb_pct = (`cb_deals' / `total_deals') * 100

count if mega_deal == 1
local mega_deals = r(N)
local mega_pct = (`mega_deals' / `total_deals') * 100

summarize car_3_market_model
local avg_car = r(mean)

summarize deal_value
local avg_deal_value = r(mean) / 1000000  // Convert to millions

// Display summary
display as text "M&A Event Study Summary:"
display as text "Total deals: " %6.0f `total_deals'
display as text "Cross-border deals: " %6.0f `cb_deals' " (" %4.1f `cb_pct' "%)"
display as text "Mega deals (≥$1B): " %6.0f `mega_deals' " (" %4.1f `mega_pct' "%)"
display as text "Average CAR [-3,+3]: " %6.4f `avg_car'
display as text "Average deal value: $" %6.0f `avg_deal_value' "M"
display as text "Cross-border effect p-value: " %6.4f `cb_p_value'

/*------------------------------------------------------------------------------
11. Export Results
------------------------------------------------------------------------------*/

// Run standard export script
do "do_files/06_export_results.do"

display as text _newline "=== M&A EVENT STUDY TEMPLATE COMPLETE ==="
display as text "M&A-specific analysis files created:"
display as text "- ${regression}/ma_analysis.csv"
display as text "- ${regression}/deal_size_analysis.csv"
display as text "- ${regression}/domestic_vs_crossborder.csv"
display as text "- ${regression}/target_efficiency_analysis.csv"
display as text "- ${regression}/ma_annual_trends.csv"
display as text "- ${outputs}/plots/ma_car_by_year.png"
