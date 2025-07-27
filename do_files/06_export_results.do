/*==============================================================================
Comprehensive Event Study Toolkit: Results Export and Visualization
================================================================================

Purpose: Export comprehensive results, create visualizations, and prepare
         publication-ready output for the event study analysis.

Author: Comprehensive Event Study Toolkit
Date: Created for academic and professional event study analysis

Input Files:
- data/processed/event_study_final.dta

Output Files:
- outputs/plots/car_distribution.png
- outputs/plots/car_time_series.png
- outputs/summary_stats/final_summary.csv
- data/processed/final_analysis_dataset.csv

Notes:
- Creates publication-ready tables and figures
- Exports data in multiple formats for further analysis
- Generates comprehensive summary documentation
- Provides visualization of key results

==============================================================================*/

// Ensure setup has been run
if "${main_dir}" == "" {
    display as error "Please run 00_setup.do first"
    exit
}

display as text _newline "=== Results Export and Visualization ==="
display as text "Creating final outputs and visualizations..."

/*------------------------------------------------------------------------------
1. Load Final Dataset
------------------------------------------------------------------------------*/

display as text _newline "1. Loading final dataset for export..."

use "${processed}/event_study_final.dta", clear

// Keep only analysis sample
keep if analysis_sample == 1

display as text "Final dataset: `c(N)' observations"

/*------------------------------------------------------------------------------
2. Create Event-Level Summary Dataset
------------------------------------------------------------------------------*/

display as text _newline "2. Creating event-level summary dataset..."

preserve
    keep if announcement_day == 1
    
    // Create comprehensive event-level dataset
    keep event_id firm_id event_date event_year event_month ///
         car_1_market_model car_3_market_model car_5_market_model car_10_market_model ///
         car_1_market_adjusted car_3_market_adjusted car_5_market_adjusted car_10_market_adjusted ///
         ar_market_model ar_market_adjusted ///
         roa leverage revenue_growth log_assets market_to_book ///
         financially_healthy high_growth large_firm ///
         ind_technology ind_finance ind_manufacturing ///
         crisis_period market_conditions avg_volatility ///
         alpha beta r_squared
    
    // Export event-level dataset
    export delimited using "${processed}/final_analysis_dataset.csv", replace
    save "${processed}/final_analysis_dataset.dta", replace
    
    local n_events = _N
restore

display as text "Event-level dataset exported: `n_events' events"

/*------------------------------------------------------------------------------
3. Create Comprehensive Summary Statistics
------------------------------------------------------------------------------*/

display as text _newline "3. Creating comprehensive summary statistics..."

preserve
    keep if announcement_day == 1
    
    // Summary statistics for all key variables
    local summary_vars "car_1_market_model car_3_market_model car_5_market_model car_10_market_model"
    local summary_vars "`summary_vars' ar_market_model roa leverage revenue_growth log_assets"
    local summary_vars "`summary_vars' market_to_book alpha beta r_squared"
    
    // Generate summary statistics
    estpost summarize `summary_vars'
    esttab using "${summary}/final_summary.csv", ///
        cells("mean(fmt(4)) sd(fmt(4)) min(fmt(4)) max(fmt(4)) count(fmt(0))") ///
        replace noobs nonumber ///
        title("Final Event Study Summary Statistics")
    
    // Generate percentile statistics
    estpost tabstat `summary_vars', statistics(p25 p50 p75) columns(statistics)
    esttab using "${summary}/percentile_summary.csv", ///
        replace noobs nonumber ///
        title("Percentile Summary Statistics")
restore

/*------------------------------------------------------------------------------
4. Create Publication-Ready Tables
------------------------------------------------------------------------------*/

display as text _newline "4. Creating publication-ready tables..."

preserve
    keep if announcement_day == 1
    
    // Table 1: Descriptive Statistics by Industry
    estpost tabstat car_3_market_model roa leverage log_assets, ///
        by(ind_technology) statistics(mean sd count) columns(statistics)
    esttab using "${summary}/descriptive_by_industry.csv", ///
        replace noobs nonumber ///
        title("Descriptive Statistics by Industry")
    
    // Table 2: Descriptive Statistics by Time Period
    estpost tabstat car_3_market_model roa leverage log_assets, ///
        by(crisis_period) statistics(mean sd count) columns(statistics)
    esttab using "${summary}/descriptive_by_period.csv", ///
        replace noobs nonumber ///
        title("Descriptive Statistics by Time Period")
    
    // Table 3: Correlation Matrix
    correlate car_3_market_model roa leverage revenue_growth log_assets market_to_book
    estpost correlate car_3_market_model roa leverage revenue_growth log_assets market_to_book, matrix
    esttab using "${summary}/correlation_matrix_final.csv", ///
        replace noobs nonumber unstack not ///
        title("Correlation Matrix of Key Variables")
restore

/*------------------------------------------------------------------------------
5. Create Visualizations
------------------------------------------------------------------------------*/

display as text _newline "5. Creating visualizations..."

preserve
    keep if announcement_day == 1
    
    // Histogram of CARs
    histogram car_3_market_model, ///
        title("Distribution of Cumulative Abnormal Returns [-3,+3]") ///
        xtitle("CAR [-3,+3]") ytitle("Density") ///
        normal
    graph export "${outputs}/plots/car_distribution.png", replace width(800) height(600)
    
    // Box plot by industry
    graph box car_3_market_model, over(ind_technology) ///
        title("CAR [-3,+3] by Technology Industry") ///
        ytitle("CAR [-3,+3]")
    graph export "${outputs}/plots/car_by_industry.png", replace width(800) height(600)
    
    // Scatter plot: CAR vs ROA
    scatter car_3_market_model roa, ///
        title("CAR [-3,+3] vs Return on Assets") ///
        xtitle("Return on Assets") ytitle("CAR [-3,+3]") ///
        msize(small)
    graph export "${outputs}/plots/car_vs_roa.png", replace width(800) height(600)
    
    // Time series of average CARs
    collapse (mean) avg_car = car_3_market_model (count) n_events = event_id, by(event_year)
    
    line avg_car event_year, ///
        title("Average CAR [-3,+3] by Year") ///
        xtitle("Year") ytitle("Average CAR [-3,+3]") ///
        lwidth(medium)
    graph export "${outputs}/plots/car_time_series.png", replace width(800) height(600)
restore

/*------------------------------------------------------------------------------
6. Create Event Study Report
------------------------------------------------------------------------------*/

display as text _newline "6. Creating event study report..."

// Create a comprehensive text report
file open report using "${outputs}/event_study_report.txt", write replace

file write report "COMPREHENSIVE EVENT STUDY ANALYSIS REPORT" _n
file write report "=========================================" _n _n

file write report "Analysis Date: $S_DATE $S_TIME" _n
file write report "Dataset: covidevent.dta" _n _n

// Load summary statistics for report
use "${processed}/final_analysis_dataset.dta", clear

summarize car_3_market_model
local mean_car = r(mean)
local sd_car = r(sd)
local n_events = r(N)

summarize car_3_market_model if car_3_market_model > 0
local pct_positive = (r(N) / `n_events') * 100

file write report "SUMMARY STATISTICS" _n
file write report "------------------" _n
file write report "Number of events: " %6.0f `n_events' _n
file write report "Mean CAR [-3,+3]: " %8.4f `mean_car' _n
file write report "Standard deviation: " %8.4f `sd_car' _n
file write report "Percentage positive: " %6.1f `pct_positive' "%" _n _n

// Industry breakdown
tab ind_technology, matcell(tech_freq)
local tech_events = tech_freq[2,1]
local tech_pct = (`tech_events' / `n_events') * 100

file write report "INDUSTRY BREAKDOWN" _n
file write report "------------------" _n
file write report "Technology firms: " %6.0f `tech_events' " (" %4.1f `tech_pct' "%)" _n

// Time period breakdown
tab crisis_period, matcell(crisis_freq)
local crisis_events = crisis_freq[2,1]
local crisis_pct = (`crisis_events' / `n_events') * 100

file write report "Crisis period events: " %6.0f `crisis_events' " (" %4.1f `crisis_pct' "%)" _n _n

file write report "FILES CREATED" _n
file write report "-------------" _n
file write report "Main results: outputs/regression_results/main_results.csv" _n
file write report "Robustness tests: outputs/regression_results/robustness_tests.csv" _n
file write report "Summary statistics: outputs/summary_stats/final_summary.csv" _n
file write report "Final dataset: data/processed/final_analysis_dataset.csv" _n
file write report "Visualizations: outputs/plots/" _n _n

file write report "METHODOLOGY" _n
file write report "-----------" _n
file write report "Abnormal returns calculated using market model" _n
file write report "Event windows: [-1,+1], [-3,+3], [-5,+5], [-10,+10]" _n
file write report "Statistical tests: t-test, sign test, Wilcoxon signed-rank" _n
file write report "Cross-sectional regressions with robust standard errors" _n

file close report

/*------------------------------------------------------------------------------
7. Create Data Dictionary
------------------------------------------------------------------------------*/

display as text _newline "7. Creating data dictionary..."

// Create data dictionary file
file open dict using "${outputs}/data_dictionary.txt", write replace

file write dict "EVENT STUDY TOOLKIT - DATA DICTIONARY" _n
file write dict "====================================" _n _n

file write dict "EVENT VARIABLES" _n
file write dict "---------------" _n
file write dict "event_id: Unique event identifier" _n
file write dict "firm_id: Firm identifier" _n
file write dict "event_date: Event announcement date" _n
file write dict "event_year: Year of event" _n
file write dict "event_month: Month of event" _n _n

file write dict "RETURN VARIABLES" _n
file write dict "----------------" _n
file write dict "car_1_market_model: CAR [-1,+1] using market model" _n
file write dict "car_3_market_model: CAR [-3,+3] using market model" _n
file write dict "car_5_market_model: CAR [-5,+5] using market model" _n
file write dict "car_10_market_model: CAR [-10,+10] using market model" _n
file write dict "ar_market_model: Abnormal return using market model" _n
file write dict "alpha: Market model intercept" _n
file write dict "beta: Market model slope" _n
file write dict "r_squared: Market model R-squared" _n _n

file write dict "FIRM CHARACTERISTICS" _n
file write dict "--------------------" _n
file write dict "roa: Return on assets" _n
file write dict "leverage: Total debt / Total assets" _n
file write dict "revenue_growth: Revenue growth rate" _n
file write dict "log_assets: Log of total assets" _n
file write dict "market_to_book: Market-to-book ratio" _n _n

file write dict "INDICATOR VARIABLES" _n
file write dict "-------------------" _n
file write dict "financially_healthy: Financially healthy firm indicator" _n
file write dict "high_growth: High growth firm indicator" _n
file write dict "large_firm: Large firm indicator (top quartile)" _n
file write dict "ind_technology: Technology industry indicator" _n
file write dict "ind_finance: Financial industry indicator" _n
file write dict "crisis_period: Crisis period indicator (2020+)" _n

file close dict

/*------------------------------------------------------------------------------
8. Final Summary and Cleanup
------------------------------------------------------------------------------*/

display as text _newline "8. Final summary and cleanup..."

// Display completion summary
display as text _newline "=== EXPORT COMPLETE ==="
display as text "Analysis completed for `n_events' events"
display as text _newline "Output files created:"
display as text "- Final dataset: ${processed}/final_analysis_dataset.csv"
display as text "- Summary report: ${outputs}/event_study_report.txt"
display as text "- Data dictionary: ${outputs}/data_dictionary.txt"
display as text "- Visualizations: ${outputs}/plots/"
display as text "- Summary statistics: ${summary}/"
display as text "- Regression results: ${regression}/"

display as text _newline "=== EVENT STUDY ANALYSIS COMPLETE ==="
display as text "All analysis files have been generated and exported."
display as text "Review the event_study_report.txt for a comprehensive summary."
display as text _newline
