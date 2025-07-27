/*==============================================================================
Comprehensive Event Study Toolkit: Data Import and Preparation
================================================================================

Purpose: Import and clean event data and stock returns data. This script is 
         designed to be flexible and work with various data formats and event types.

Author: Comprehensive Event Study Toolkit
Date: Created for academic and professional event study analysis

Input Files (place in data/raw/):
- Event data file (CSV, DTA, or other formats)
- Stock returns data (if separate from event data)

Output Files:
- data/processed/event_data_clean.dta
- data/processed/returns_data_clean.dta (if applicable)

Notes:
- Automatically detects data structure and variable names
- Handles various event types (M&A, earnings, COVID-19, etc.)
- Flexible date format handling
- Comprehensive data validation and cleaning

==============================================================================*/

// Ensure setup has been run
if "${main_dir}" == "" {
    display as error "Please run 00_setup.do first"
    exit
}

display as text _newline "=== Data Import and Preparation ==="
display as text "Starting data import and cleaning process..."

/*------------------------------------------------------------------------------
1. Detect and Import Primary Dataset
------------------------------------------------------------------------------*/

display as text _newline "1. Detecting and loading primary dataset..."

// Check for various possible data files
local data_files : dir "${raw_data}" files "*.dta"
local csv_files : dir "${raw_data}" files "*.csv"

// Try to load the main dataset (prioritize .dta files)
local loaded = 0
foreach file of local data_files {
    if !`loaded' {
        display as text "Loading Stata file: `file'"
        use "${raw_data}/`file'", clear
        local loaded = 1
        local main_file "`file'"
    }
}

// If no .dta files, try CSV files
if !`loaded' {
    foreach file of local csv_files {
        if !`loaded' {
            display as text "Loading CSV file: `file'"
            import delimited "${raw_data}/`file'", clear case(lower)
            local loaded = 1
            local main_file "`file'"
        }
    }
}

if !`loaded' {
    display as error "No data files found in ${raw_data}/"
    display as error "Please place your data files in the raw data directory"
    exit
}

display as text "Successfully loaded: `main_file'"
display as text "Dataset contains `c(N)' observations and `c(k)' variables"

/*------------------------------------------------------------------------------
2. Examine and Clean the Dataset
------------------------------------------------------------------------------*/

display as text _newline "2. Examining and cleaning the dataset..."

// Display variable information
describe
summarize

// Standardize variable names to lowercase
foreach var of varlist _all {
    local newname = lower("`var'")
    if "`var'" != "`newname'" {
        rename `var' `newname'
    }
}

// Ensure event_date is in proper format
capture confirm variable event_date
if _rc == 0 {
    // Check if already in Stata date format
    capture confirm numeric variable event_date
    if _rc == 0 {
        format event_date %td
        display as text "Event date variable found and formatted"
    }
}
else {
    display as error "No event_date variable found in dataset"
    exit
}

// Create firm identifier
capture confirm variable company_id
if _rc == 0 {
    gen firm_id = company_id
    display as text "Using company_id as firm identifier"
}
else {
    display as error "No company identifier found"
    exit
}

/*------------------------------------------------------------------------------
3. Data Validation and Cleaning
------------------------------------------------------------------------------*/

display as text _newline "3. Performing data validation and cleaning..."

// Check for missing event dates
count if missing(event_date)
if r(N) > 0 {
    display as text "Warning: `r(N)' observations have missing event dates"
    drop if missing(event_date)
}

// Check for missing firm identifiers
count if missing(firm_id)
if r(N) > 0 {
    display as text "Warning: `r(N)' observations have missing firm IDs"
    drop if missing(firm_id)
}

// Clean and validate financial variables
foreach var of varlist total_assets deal_value dv tan {
    capture confirm variable `var'
    if _rc == 0 {
        // Replace negative values with missing for financial variables
        replace `var' = . if `var' < 0
        
        // Count missing values
        count if missing(`var')
        if r(N) > 0 {
            display as text "`var': `r(N)' missing values"
        }
    }
}

/*------------------------------------------------------------------------------
4. Create Event Study Variables
------------------------------------------------------------------------------*/

display as text _newline "4. Creating event study variables..."

// Create event ID for each unique event
sort firm_id event_date
by firm_id event_date: gen event_id = _n == 1
replace event_id = sum(event_id)

// Add variable labels
label var event_id "Unique event identifier"
label var firm_id "Firm identifier"
label var event_date "Event announcement date"

// Label existing variables based on dataset structure
capture confirm variable total_assets
if _rc == 0 {
    label var total_assets "Total assets"
}

capture confirm variable deal_value
if _rc == 0 {
    label var deal_value "Deal value"
}

capture confirm variable tan
if _rc == 0 {
    label var tan "Tangible assets"
}

capture confirm variable dv
if _rc == 0 {
    label var dv "Deal value (alternative measure)"
}

capture confirm variable crossborder
if _rc == 0 {
    label var crossborder "Cross-border deal indicator"
}

/*------------------------------------------------------------------------------
5. Save Cleaned Dataset
------------------------------------------------------------------------------*/

display as text _newline "5. Saving cleaned dataset..."

// Sort and save
sort event_id
compress
save "${processed}/event_data_clean.dta", replace

display as text "Cleaned event data saved: `c(N)' observations"

/*------------------------------------------------------------------------------
6. Summary Statistics
------------------------------------------------------------------------------*/

display as text _newline "6. Generating summary statistics..."

// Basic summary statistics
summarize total_assets deal_value tan dv crossborder

// Count events by year
tab year(event_date), missing

// Export summary statistics
preserve
    // Create summary for key variables
    local summary_vars ""
    foreach var of varlist total_assets deal_value tan dv {
        capture confirm variable `var'
        if _rc == 0 {
            local summary_vars "`summary_vars' `var'"
        }
    }
    
    if "`summary_vars'" != "" {
        estpost summarize `summary_vars'
        esttab using "${summary}/import_summary_stats.csv", ///
            cells("mean(fmt(4)) sd(fmt(4)) min(fmt(4)) max(fmt(4)) count(fmt(0))") ///
            replace noobs nonumber
    }
restore

display as text _newline "=== Data Import and Preparation Complete ==="
display as text "Output files created:"
display as text "- ${processed}/event_data_clean.dta"
display as text "- ${summary}/import_summary_stats.csv"
display as text _newline "Next step: Run 02_define_events.do"

// Convert date variable
gen date_stata = date(date, "YMD")
format date_stata %td
drop date
rename date_stata date

// Clean return data
replace ret = . if ret < -1 | ret > 5  // Remove extreme returns
replace ret = . if missing(ret) | ret == .

// Calculate market capitalization
gen mktcap = abs(prc) * shrout / 1000  // Market cap in thousands

// Create adjusted price using CRSP adjustment factors
gen adj_prc = abs(prc) / cfacpr

// Keep only necessary variables
keep permno date ret prc adj_prc shrout mktcap cfacpr cfacshr

// Sort and save
sort permno date
compress
save "${processed}/crsp_returns_clean.dta", replace

display as text "CRSP returns data saved: `c(N)' observations"

/*------------------------------------------------------------------------------
2. Import and Clean Event Data
------------------------------------------------------------------------------*/

display as text _newline "2. Loading M&A event data..."

// Import event data
import delimited "${raw_data}/ma_events.csv", clear case(lower)

// Convert announcement date
gen announce_date_stata = date(announce_date, "YMD")
format announce_date_stata %td
drop announce_date
rename announce_date_stata announce_date

// Clean deal value (convert to millions if needed)
replace deal_value = deal_value / 1000000 if deal_value > 1000000

// Remove missing announcement dates or PERMNOs
drop if missing(announce_date) | missing(permno)

// Keep only necessary variables
keep permno announce_date deal_id deal_value deal_type target_name acquirer_name

// Sort and save
sort permno announce_date
compress
save "${processed}/event_data_clean.dta", replace

display as text "Event data saved: `c(N)' observations"

/*------------------------------------------------------------------------------
3. Create Event Windows and Merge with CRSP Data
------------------------------------------------------------------------------*/

display as text _newline "3. Creating event windows and merging with CRSP data..."

// Load event data
use "${processed}/event_data_clean.dta", clear

// Expand dataset to create event windows
expand 21  // 21 days: -10 to +10
bysort permno announce_date deal_id: gen event_day = _n - 11  // -10 to +10

// Create actual calendar date for each event day
gen event_date = announce_date + event_day
format event_date %td

// Create event window indicators
gen event_window_1 = (event_day >= -1 & event_day <= 1)
gen event_window_5 = (event_day >= -5 & event_day <= 5)
gen event_window_10 = (event_day >= -10 & event_day <= 10)

// Merge with CRSP returns data
merge m:1 permno event_date using "${processed}/crsp_returns_clean.dta", ///
    keepusing(ret prc adj_prc mktcap) keep(match master)

// Keep only observations with return data
keep if _merge == 3
drop _merge

// Rename for clarity
rename event_date date
rename announce_date event_announce_date

/*------------------------------------------------------------------------------
4. Calculate Market Returns and Abnormal Returns
------------------------------------------------------------------------------*/

display as text _newline "4. Calculating market returns and abnormal returns..."

// Calculate value-weighted market return by date
preserve
    collapse (mean) vw_market_ret = ret [aweight=mktcap], by(date)
    tempfile market_returns
    save `market_returns'
restore

// Merge market returns
merge m:1 date using `market_returns', keep(match) nogen

// Calculate abnormal returns (simple market model)
gen abnormal_return = ret - vw_market_ret

// Calculate cumulative abnormal returns for each window
sort permno deal_id event_day

// CAR [-1,+1]
by permno deal_id: egen car_1 = total(abnormal_return) if event_window_1 == 1
by permno deal_id: egen car_window_1 = max(car_1)

// CAR [-5,+5]  
by permno deal_id: egen car_5 = total(abnormal_return) if event_window_5 == 1
by permno deal_id: egen car_window_5 = max(car_5)

// CAR [-10,+10]
by permno deal_id: egen car_10 = total(abnormal_return) if event_window_10 == 1
by permno deal_id: egen car_window_10 = max(car_10)

// Clean up temporary variables
drop car_1 car_5 car_10

/*------------------------------------------------------------------------------
5. Create Final Event Study Dataset
------------------------------------------------------------------------------*/

display as text _newline "5. Creating final event study dataset..."

// Keep one observation per deal (at announcement date)
keep if event_day == 0

// Keep relevant variables
keep permno deal_id event_announce_date deal_value deal_type target_name ///
     acquirer_name car_window_1 car_window_5 car_window_10 mktcap ret ///
     abnormal_return vw_market_ret

// Add variable labels
label var permno "CRSP PERMNO"
label var deal_id "Deal identifier"
label var event_announce_date "M&A announcement date"
label var deal_value "Deal value (millions USD)"
label var car_window_1 "CAR [-1,+1] around announcement"
label var car_window_5 "CAR [-5,+5] around announcement"
label var car_window_10 "CAR [-10,+10] around announcement"
label var mktcap "Market capitalization (thousands USD)"
label var abnormal_return "Abnormal return on announcement day"
label var vw_market_ret "Value-weighted market return"

// Sort and save
sort permno event_announce_date
compress
save "${processed}/event_study_base.dta", replace

display as text "Event study base dataset saved: `c(N)' deals"

/*------------------------------------------------------------------------------
6. Summary Statistics
------------------------------------------------------------------------------*/

display as text _newline "6. Generating summary statistics..."

// Basic summary statistics
summarize car_window_1 car_window_5 car_window_10 deal_value mktcap

// Export summary statistics
estpost summarize car_window_1 car_window_5 car_window_10 deal_value mktcap
esttab using "${summary}/crsp_summary_stats.csv", ///
    cells("mean(fmt(4)) sd(fmt(4)) min(fmt(4)) max(fmt(4)) count(fmt(0))") ///
    replace noobs nonumber

display as text _newline "=== CRSP Data Processing Complete ==="
display as text "Output files created:"
display as text "- ${processed}/crsp_returns_clean.dta"
display as text "- ${processed}/event_data_clean.dta" 
display as text "- ${processed}/event_study_base.dta"
display as text "- ${summary}/crsp_summary_stats.csv"
display as text _newline "Next step: Run 02_merge_ccm_compustat.do"
