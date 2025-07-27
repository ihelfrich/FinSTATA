/*==============================================================================
Event Study Toolkit: Datastream Data Merge (Optional)
================================================================================

Purpose: Merge additional deal-level variables from Datastream by CUSIP or ticker.
         Uses Python helper script for CUSIP cleaning and standardization.

Author: Event Study Toolkit
Date: Created for academic and professional event study analysis

Input Files (place in data/raw/):
- datastream_deals.csv: Datastream deal-level data with CUSIP/ticker
- cusip_mapping.csv: Additional CUSIP mapping if needed

Output Files:
- data/processed/event_study_with_datastream.dta

Notes:
- This script is optional - skip if not using Datastream data
- Requires Python helper script for CUSIP cleaning
- Merges by CUSIP (preferred) or ticker symbol
- Adds deal characteristics like advisor fees, method of payment, etc.

==============================================================================*/

// Ensure setup has been run
if "${main_dir}" == "" {
    display as error "Please run 00_setup.do first"
    exit
}

display as text _newline "=== Datastream Data Merge (Optional) ==="
display as text "Starting Datastream data integration..."

/*------------------------------------------------------------------------------
1. Check for Datastream Data Files
------------------------------------------------------------------------------*/

display as text _newline "1. Checking for Datastream data files..."

// Check if Datastream file exists
capture confirm file "${raw_data}/datastream_deals.csv"
if _rc != 0 {
    display as text "Datastream file not found. Skipping Datastream merge."
    display as text "To use Datastream data, place datastream_deals.csv in data/raw/"
    display as text "Continuing without Datastream data..."
    
    // Copy existing file and exit
    use "${processed}/event_study_with_compustat.dta", clear
    save "${processed}/event_study_with_datastream.dta", replace
    
    display as text "File copied to event_study_with_datastream.dta"
    display as text "Next step: Run 04_create_variables.do"
    exit
}

/*------------------------------------------------------------------------------
2. Load Base Event Study Data
------------------------------------------------------------------------------*/

display as text _newline "2. Loading base event study data..."

use "${processed}/event_study_with_compustat.dta", clear

// Extract CUSIP from CRSP if available (you may need to add this to CRSP import)
// For now, we'll work with what we have
gen cusip = ""  // Placeholder - replace with actual CUSIP from CRSP data
gen ticker = ""  // Placeholder - replace with actual ticker from CRSP data

display as text "Base data loaded: `c(N)' deals"

/*------------------------------------------------------------------------------
3. Clean CUSIPs Using Python Helper
------------------------------------------------------------------------------*/

display as text _newline "3. Cleaning CUSIPs using Python helper..."

// Export data for Python CUSIP cleaning
preserve
    keep permno deal_id cusip ticker
    drop if missing(cusip) & missing(ticker)
    export delimited "${processed}/temp_cusip_input.csv", replace
restore

// Run Python CUSIP cleaner
shell python "${helpers}/cusip_cleaner.py" "${processed}/temp_cusip_input.csv" "${processed}/temp_cusip_clean.csv"

// Check if Python script succeeded
capture confirm file "${processed}/temp_cusip_clean.csv"
if _rc != 0 {
    display as error "Python CUSIP cleaner failed. Check cusip_cleaner.py"
    display as text "Continuing without CUSIP cleaning..."
}
else {
    display as text "CUSIP cleaning completed successfully"
    
    // Merge back cleaned CUSIPs
    preserve
        import delimited "${processed}/temp_cusip_clean.csv", clear case(lower)
        tempfile clean_cusips
        save `clean_cusips'
    restore
    
    merge 1:1 permno deal_id using `clean_cusips', ///
        update replace keep(match master) nogen
}

/*------------------------------------------------------------------------------
4. Import and Clean Datastream Data
------------------------------------------------------------------------------*/

display as text _newline "4. Loading Datastream deal data..."

preserve
    import delimited "${raw_data}/datastream_deals.csv", clear case(lower)
    
    // Clean Datastream data
    // Convert dates if needed
    capture {
        gen announce_date_ds = date(announce_date, "YMD")
        format announce_date_ds %td
        drop announce_date
        rename announce_date_ds announce_date
    }
    
    // Clean CUSIP in Datastream data
    replace cusip = subinstr(cusip, " ", "", .)
    replace cusip = upper(cusip)
    
    // Keep relevant variables (modify based on your Datastream data)
    keep cusip ticker announce_date deal_value_ds advisor_fees ///
         payment_method deal_attitude premium_1day premium_1week ///
         target_industry acquirer_industry deal_status
    
    // Remove duplicates
    duplicates drop cusip announce_date, force
    
    tempfile datastream_data
    save `datastream_data'
restore

/*------------------------------------------------------------------------------
5. Merge with Datastream Data
------------------------------------------------------------------------------*/

display as text _newline "5. Merging with Datastream data..."

// First try merging by CUSIP and announcement date
merge 1:1 cusip event_announce_date using `datastream_data', ///
    keep(match master) keepusing(deal_value_ds advisor_fees payment_method ///
    deal_attitude premium_1day premium_1week target_industry acquirer_industry deal_status)

gen datastream_match_cusip = (_merge == 3)
drop _merge

// For unmatched observations, try merging by ticker
preserve
    use `datastream_data', clear
    drop cusip announce_date
    duplicates drop ticker, force
    tempfile datastream_ticker
    save `datastream_ticker'
restore

merge m:1 ticker using `datastream_ticker', ///
    keep(match master) update replace
    
gen datastream_match_ticker = (_merge == 3 & datastream_match_cusip == 0)
drop _merge

/*------------------------------------------------------------------------------
6. Create Datastream-Based Variables
------------------------------------------------------------------------------*/

display as text _newline "6. Creating Datastream-based variables..."

// Deal characteristics
gen has_advisor_fees = !missing(advisor_fees)
label var has_advisor_fees "Deal has advisor fee information"

// Payment method indicators
gen cash_deal = (payment_method == "Cash" | payment_method == "CASH")
gen stock_deal = (payment_method == "Stock" | payment_method == "STOCK")
gen mixed_deal = (payment_method == "Mixed" | payment_method == "MIXED")

label var cash_deal "Cash-only deal"
label var stock_deal "Stock-only deal" 
label var mixed_deal "Mixed payment deal"

// Deal attitude
gen hostile_deal = (deal_attitude == "Hostile" | deal_attitude == "HOSTILE")
gen friendly_deal = (deal_attitude == "Friendly" | deal_attitude == "FRIENDLY")

label var hostile_deal "Hostile takeover"
label var friendly_deal "Friendly deal"

// Premium variables (if available)
gen premium_1d = premium_1day / 100 if !missing(premium_1day)
gen premium_1w = premium_1week / 100 if !missing(premium_1week)

label var premium_1d "1-day announcement premium"
label var premium_1w "1-week announcement premium"

// Industry indicators (create dummies for major industries)
gen target_tech = (target_industry == "Technology" | target_industry == "TECH")
gen target_finance = (target_industry == "Financial" | target_industry == "FINANCE")
gen target_healthcare = (target_industry == "Healthcare" | target_industry == "HEALTH")

label var target_tech "Target in technology industry"
label var target_finance "Target in financial industry"
label var target_healthcare "Target in healthcare industry"

/*------------------------------------------------------------------------------
7. Data Quality Checks
------------------------------------------------------------------------------*/

display as text _newline "7. Performing data quality checks..."

// Check merge success rates
count if datastream_match_cusip == 1
local cusip_matches = r(N)
count if datastream_match_ticker == 1  
local ticker_matches = r(N)
count
local total_deals = r(N)

display as text "Datastream merge results:"
display as text "- CUSIP matches: `cusip_matches' / `total_deals' (`=round(100*`cusip_matches'/`total_deals', 0.1)'%)"
display as text "- Ticker matches: `ticker_matches' / `total_deals' (`=round(100*`ticker_matches'/`total_deals', 0.1)'%)"
display as text "- Total with Datastream: `=`cusip_matches'+`ticker_matches'' / `total_deals' (`=round(100*(`cusip_matches'+`ticker_matches')/`total_deals', 0.1)'%)"

// Create overall Datastream indicator
gen has_datastream = (datastream_match_cusip == 1 | datastream_match_ticker == 1)
label var has_datastream "Has Datastream deal information"

/*------------------------------------------------------------------------------
8. Clean Up and Save
------------------------------------------------------------------------------*/

display as text _newline "8. Cleaning up and saving final dataset..."

// Drop temporary variables
drop datastream_match_cusip datastream_match_ticker

// Add variable labels for Datastream variables
label var advisor_fees "Advisor fees (millions USD)"
label var payment_method "Method of payment"
label var deal_attitude "Deal attitude (friendly/hostile)"
label var deal_status "Deal completion status"

// Clean up temporary files
capture erase "${processed}/temp_cusip_input.csv"
capture erase "${processed}/temp_cusip_clean.csv"

// Sort and save
sort permno event_announce_date
compress
save "${processed}/event_study_with_datastream.dta", replace

/*------------------------------------------------------------------------------
9. Summary Statistics
------------------------------------------------------------------------------*/

display as text _newline "9. Generating summary statistics..."

// Summary of Datastream variables
summarize advisor_fees premium_1d premium_1w if has_datastream == 1

// Frequency tables for categorical variables
tab payment_method if has_datastream == 1
tab deal_attitude if has_datastream == 1
tab has_datastream

// Export summary statistics
preserve
    keep if has_datastream == 1
    estpost summarize advisor_fees premium_1d premium_1w
    esttab using "${summary}/datastream_summary_stats.csv", ///
        cells("mean(fmt(4)) sd(fmt(4)) min(fmt(4)) max(fmt(4)) count(fmt(0))") ///
        replace noobs nonumber
restore

display as text _newline "=== Datastream Merge Complete ==="
display as text "Output files created:"
display as text "- ${processed}/event_study_with_datastream.dta"
display as text "- ${summary}/datastream_summary_stats.csv"
display as text _newline "Next step: Run 04_create_variables.do"
