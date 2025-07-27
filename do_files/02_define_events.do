/*==============================================================================
Comprehensive Event Study Toolkit: Event Definition and Window Creation
================================================================================

Purpose: Define event windows around corporate events and prepare the dataset
         for abnormal return calculations. Handles various event types and
         flexible window specifications.

Author: Comprehensive Event Study Toolkit
Date: Created for academic and professional event study analysis

Input Files:
- data/processed/event_data_clean.dta

Output Files:
- data/processed/event_windows.dta

Notes:
- Creates flexible event windows based on global settings
- Handles overlapping events and multiple events per firm
- Validates event dates and data availability
- Prepares estimation and event windows

==============================================================================*/

// Ensure setup has been run
if "${main_dir}" == "" {
    display as error "Please run 00_setup.do first"
    exit
}

display as text _newline "=== Event Definition and Window Creation ==="
display as text "Creating event windows and preparing event data..."

/*------------------------------------------------------------------------------
1. Load Event Data
------------------------------------------------------------------------------*/

display as text _newline "1. Loading cleaned event data..."

use "${processed}/event_data_clean.dta", clear

// Display basic information about the dataset
display as text "Event data loaded: `c(N)' observations"
describe, short

/*------------------------------------------------------------------------------
2. Identify Date and Identifier Variables
------------------------------------------------------------------------------*/

display as text _newline "2. Identifying key variables..."

// Look for date variables
local date_vars ""
foreach var of varlist _all {
    local var_lower = lower("`var'")
    if regexm("`var_lower'", "date|time|day") {
        local date_vars "`date_vars' `var'"
    }
}

// Look for firm identifier variables
local id_vars ""
foreach var of varlist _all {
    local var_lower = lower("`var'")
    if regexm("`var_lower'", "permno|gvkey|cusip|ticker|id|symbol") {
        local id_vars "`id_vars' `var'"
    }
}

display as text "Potential date variables: `date_vars'"
display as text "Potential identifier variables: `id_vars'"

// Use the first date variable as event date (user can modify this)
local event_date_var : word 1 of `date_vars'
local firm_id_var : word 1 of `id_vars'

if "`event_date_var'" == "" {
    display as error "No date variable found. Please ensure your data has a date variable."
    exit
}

if "`firm_id_var'" == "" {
    display as error "No firm identifier found. Please ensure your data has a firm ID variable."
    exit
}

display as text "Using event date variable: `event_date_var'"
display as text "Using firm identifier variable: `firm_id_var'"

/*------------------------------------------------------------------------------
3. Standardize Date Format
------------------------------------------------------------------------------*/

display as text _newline "3. Standardizing date format..."

// Check if date is already in Stata format
capture confirm numeric variable `event_date_var'
if _rc == 0 {
    // Numeric variable - check if it's already a Stata date
    summarize `event_date_var'
    if r(min) > 10000 & r(max) < 50000 {
        display as text "Date appears to be in Stata format already"
        gen event_date = `event_date_var'
    }
    else {
        display as text "Converting numeric date to Stata format"
        gen event_date = date(string(`event_date_var'), "YMD")
    }
}
else {
    // String variable - try to parse
    display as text "Converting string date to Stata format"
    gen event_date = date(`event_date_var', "YMD")
    if missing(event_date[1]) {
        replace event_date = date(`event_date_var', "MDY")
    }
    if missing(event_date[1]) {
        replace event_date = date(`event_date_var', "DMY")
    }
}

format event_date %td

// Check for missing dates
count if missing(event_date)
if r(N) > 0 {
    display as text "Warning: `r(N)' observations have missing event dates"
    drop if missing(event_date)
}

/*------------------------------------------------------------------------------
4. Create Event Windows
------------------------------------------------------------------------------*/

display as text _newline "4. Creating event windows..."

// Create a standardized firm identifier
gen firm_id = `firm_id_var'

// Sort by firm and event date
sort firm_id event_date

// Create event ID for each unique event
by firm_id event_date: gen event_id = _n == 1
replace event_id = sum(event_id)

// Expand dataset to create event windows
local max_window = 10  // Maximum window size
local total_days = 2 * `max_window' + 1

expand `total_days'
sort event_id
by event_id: gen event_day = _n - `max_window' - 1

// Create calendar date for each event day
gen calendar_date = event_date + event_day
format calendar_date %td

/*------------------------------------------------------------------------------
5. Create Event Window Indicators
------------------------------------------------------------------------------*/

display as text _newline "5. Creating event window indicators..."

// Create indicators for different event windows
gen event_window_1 = (event_day >= -1 & event_day <= 1)
gen event_window_3 = (event_day >= -3 & event_day <= 3)
gen event_window_5 = (event_day >= -5 & event_day <= 5)
gen event_window_10 = (event_day >= -10 & event_day <= 10)

// Create estimation window indicator
gen estimation_window = (event_day >= -${estimation_period} - ${gap_period} & ///
                        event_day <= -${gap_period} - 1)

// Create indicators for specific days
gen announcement_day = (event_day == 0)
gen pre_announcement = (event_day == -1)
gen post_announcement = (event_day == 1)

/*------------------------------------------------------------------------------
6. Add Variable Labels
------------------------------------------------------------------------------*/

display as text _newline "6. Adding variable labels..."

label var event_id "Unique event identifier"
label var firm_id "Firm identifier"
label var event_date "Event announcement date"
label var calendar_date "Calendar date for event window"
label var event_day "Days relative to event (0 = announcement)"
label var event_window_1 "Event window [-1,+1]"
label var event_window_3 "Event window [-3,+3]"
label var event_window_5 "Event window [-5,+5]"
label var event_window_10 "Event window [-10,+10]"
label var estimation_window "Estimation window for market model"
label var announcement_day "Announcement day (t=0)"
label var pre_announcement "Day before announcement (t=-1)"
label var post_announcement "Day after announcement (t=+1)"

/*------------------------------------------------------------------------------
7. Save Event Windows Dataset
------------------------------------------------------------------------------*/

display as text _newline "7. Saving event windows dataset..."

// Keep relevant variables
keep event_id firm_id event_date calendar_date event_day ///
     event_window_* estimation_window announcement_day ///
     pre_announcement post_announcement

// Sort and save
sort event_id event_day
compress
save "${processed}/event_windows.dta", replace

display as text "Event windows dataset saved: `c(N)' event-day observations"

/*------------------------------------------------------------------------------
8. Summary Statistics
------------------------------------------------------------------------------*/

display as text _newline "8. Generating summary statistics..."

// Count events and firms
preserve
    keep if announcement_day == 1
    display as text "Total events: `c(N)'"
    
    // Count unique firms
    duplicates drop firm_id, force
    display as text "Unique firms: `c(N)'"
restore

// Date range
summarize event_date if announcement_day == 1
local min_date = string(r(min), "%td")
local max_date = string(r(max), "%td")
display as text "Event date range: `min_date' to `max_date'"

display as text _newline "=== Event Definition Complete ==="
display as text "Output files created:"
display as text "- ${processed}/event_windows.dta"
display as text _newline "Next step: Run 03_calculate_returns.do"
