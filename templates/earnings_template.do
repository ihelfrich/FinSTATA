/*==============================================================================
Earnings Announcement Event Study Template
================================================================================

Purpose: Template for analyzing earnings announcement events using the
         comprehensive event study toolkit. Demonstrates adaptation for
         quarterly earnings releases.

Author: Comprehensive Event Study Toolkit
Date: Created for earnings announcement event study analysis

Notes:
- This template demonstrates how to adapt the toolkit for earnings events
- Focuses on earnings surprises and firm performance measures
- Shows quarterly and annual analysis patterns

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

// Set earnings-specific parameters
global min_market_cap = 100000000  // Minimum market cap ($100M)
global earnings_season_months "1 4 7 10"  // Typical earnings months

/*------------------------------------------------------------------------------
2. Data Import and Preparation
------------------------------------------------------------------------------*/

// Import earnings announcement data
do "do_files/01_import_data.do"

// Define event windows around earnings announcements
do "do_files/02_define_events.do"

// Calculate abnormal returns
do "do_files/03_calculate_returns.do"

/*------------------------------------------------------------------------------
3. Earnings-Specific Variable Creation
------------------------------------------------------------------------------*/

// Load the dataset for earnings-specific modifications
use "${processed}/abnormal_returns.dta", clear

// Create earnings-specific variables (adapt based on your data)
gen earnings_season = inlist(month(event_date), 1, 4, 7, 10)
label var earnings_season "Earnings season month"

// Create quarterly indicators
gen q1_earnings = (month(event_date) == 4)
gen q2_earnings = (month(event_date) == 7)
gen q3_earnings = (month(event_date) == 10)
gen q4_earnings = (month(event_date) == 1)

label var q1_earnings "Q1 earnings announcement"
label var q2_earnings "Q2 earnings announcement"
label var q3_earnings "Q3 earnings announcement"
label var q4_earnings "Q4 earnings announcement"

// Save earnings-enhanced dataset
save "${processed}/earnings_abnormal_returns.dta", replace

/*------------------------------------------------------------------------------
4. Create Earnings-Specific Variables
------------------------------------------------------------------------------*/

// Run standard variable creation
do "do_files/04_create_variables.do"

// Load final dataset for additional earnings variables
use "${processed}/event_study_final.dta", clear

// Create earnings-specific interactions
gen large_firm_q4 = large_firm * q4_earnings
gen covid_earnings = covid_period * earnings_season

label var large_firm_q4 "Large Firm × Q4 Earnings"
label var covid_earnings "COVID × Earnings Season"

// Save earnings-enhanced dataset
save "${processed}/earnings_event_study_final.dta", replace

/*------------------------------------------------------------------------------
5. Earnings-Specific Analysis
------------------------------------------------------------------------------*/

// Keep only announcement day observations for analysis
keep if announcement_day == 1 & analysis_sample == 1

// Earnings Season Analysis
display as text _newline "=== EARNINGS SEASON ANALYSIS ==="

eststo clear

// Model 1: Basic earnings season effects
eststo earn1: regress car_3_market_model earnings_season, robust

// Model 2: Quarterly effects
eststo earn2: regress car_3_market_model q1_earnings q2_earnings q3_earnings q4_earnings, robust

// Model 3: Add firm characteristics
eststo earn3: regress car_3_market_model q1_earnings q2_earnings q3_earnings q4_earnings ///
              log_assets tangible_ratio, robust

// Model 4: Add COVID effects
eststo earn4: regress car_3_market_model q1_earnings q2_earnings q3_earnings q4_earnings ///
              log_assets tangible_ratio covid_period covid_earnings, robust

// Export earnings analysis results
esttab earn1 earn2 earn3 earn4 using "${regression}/earnings_analysis.csv", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Earnings Announcement Analysis") ///
    mtitles("Basic" "Quarterly" "Firm Chars" "COVID Effects") ///
    addnotes("Robust standard errors in parentheses" "* p<0.10, ** p<0.05, *** p<0.01")

/*------------------------------------------------------------------------------
6. Quarterly Analysis
------------------------------------------------------------------------------*/

display as text _newline "=== QUARTERLY ANALYSIS ==="

// Test for differences across quarters
eststo clear

eststo q1: regress car_3_market_model log_assets tangible_ratio if q1_earnings == 1, robust
eststo q2: regress car_3_market_model log_assets tangible_ratio if q2_earnings == 1, robust
eststo q3: regress car_3_market_model log_assets tangible_ratio if q3_earnings == 1, robust
eststo q4: regress car_3_market_model log_assets tangible_ratio if q4_earnings == 1, robust

esttab q1 q2 q3 q4 using "${regression}/quarterly_analysis.csv", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    title("Analysis by Quarter") ///
    mtitles("Q1" "Q2" "Q3" "Q4") ///
    addnotes("Robust standard errors in parentheses" "* p<0.10, ** p<0.05, *** p<0.01")

/*------------------------------------------------------------------------------
7. Summary and Key Findings
------------------------------------------------------------------------------*/

display as text _newline "=== EARNINGS EVENT STUDY SUMMARY ==="

// Calculate key statistics by quarter
foreach q in q1 q2 q3 q4 {
    summarize car_3_market_model if `q'_earnings == 1
    local `q'_car = r(mean)
    local `q'_n = r(N)
}

// Display summary
display as text "Average CAR [-3,+3] by quarter:"
display as text "Q1: " %6.4f `q1_car' " (n=" %4.0f `q1_n' ")"
display as text "Q2: " %6.4f `q2_car' " (n=" %4.0f `q2_n' ")"
display as text "Q3: " %6.4f `q3_car' " (n=" %4.0f `q3_n' ")"
display as text "Q4: " %6.4f `q4_car' " (n=" %4.0f `q4_n' ")"

/*------------------------------------------------------------------------------
8. Export Results
------------------------------------------------------------------------------*/

// Run standard export script
do "do_files/06_export_results.do"

display as text _newline "=== EARNINGS EVENT STUDY TEMPLATE COMPLETE ==="
display as text "Earnings-specific analysis files created:"
display as text "- ${regression}/earnings_analysis.csv"
display as text "- ${regression}/quarterly_analysis.csv"
