/*==============================================================================
Event Study Toolkit: CCM Link and Compustat Merge
================================================================================

Purpose: Merge CRSP data with Compustat accounting variables using the 
         CRSP/Compustat Merged (CCM) link table. Links PERMNO to GVKEY
         and matches accounting data from the last fiscal year before each event.

Author: Event Study Toolkit
Date: Created for academic and professional event study analysis

Input Files (place in data/raw/):
- ccm_link.csv: CRSP/Compustat Merged link table
- compustat_annual.csv: Compustat Fundamentals Annual data

Output Files:
- data/processed/event_study_with_compustat.dta

Notes:
- Uses only primary links: linktype in ("LU", "LC") and linkprim in ("P", "C")
- Matches accounting data from fiscal year-end before announcement date
- Requires Compustat variables: gvkey, datadate, fyear, at, ni, sale, debt, etc.

==============================================================================*/

// Ensure setup has been run
if "${main_dir}" == "" {
    display as error "Please run 00_setup.do first"
    exit
}

display as text _newline "=== CCM Link and Compustat Merge ==="
display as text "Starting CCM linking process..."

/*------------------------------------------------------------------------------
1. Import and Clean CCM Link Table
------------------------------------------------------------------------------*/

display as text _newline "1. Loading CCM link table..."

// Import CCM link data
import delimited "${raw_data}/ccm_link.csv", clear case(lower)

// Convert link dates
gen linkdt_stata = date(linkdt, "YMD")
gen linkenddt_stata = date(linkenddt, "YMD")
format linkdt_stata linkenddt_stata %td
drop linkdt linkenddt
rename linkdt_stata linkdt
rename linkenddt_stata linkenddt

// Keep only primary links
keep if inlist(linktype, "LU", "LC")
keep if inlist(linkprim, "P", "C")

// Handle missing link end dates (ongoing links)
replace linkenddt = date("31dec2030", "DMY") if missing(linkenddt)

// Keep necessary variables
keep gvkey permno linkdt linkenddt linktype linkprim

// Remove duplicates and sort
duplicates drop
sort permno linkdt

// Save cleaned link table
save "${processed}/ccm_link_clean.dta", replace

display as text "CCM link table saved: `c(N)' links"

/*------------------------------------------------------------------------------
2. Import and Clean Compustat Data
------------------------------------------------------------------------------*/

display as text _newline "2. Loading Compustat annual data..."

// Import Compustat data
import delimited "${raw_data}/compustat_annual.csv", clear case(lower)

// Convert data date
gen datadate_stata = date(datadate, "YMD")
format datadate_stata %td
drop datadate
rename datadate_stata datadate

// Keep only necessary variables (add more as needed)
keep gvkey datadate fyear at ni sale debt lt dlc che revt cogs xsga ///
     csho prcc_f mkvalt ceq seq txdb itcb dp am intan

// Remove observations with missing key variables
drop if missing(gvkey) | missing(datadate) | missing(fyear)
drop if missing(at) | at <= 0  // Total assets must be positive

// Sort and save
sort gvkey fyear
compress
save "${processed}/compustat_annual_clean.dta", replace

display as text "Compustat annual data saved: `c(N)' firm-years"

/*------------------------------------------------------------------------------
3. Load Event Study Base Data
------------------------------------------------------------------------------*/

display as text _newline "3. Loading event study base data..."

use "${processed}/event_study_base.dta", clear

// Create year variable from announcement date
gen announce_year = year(event_announce_date)

display as text "Event study base data loaded: `c(N)' deals"

/*------------------------------------------------------------------------------
4. Link CRSP to Compustat via CCM
------------------------------------------------------------------------------*/

display as text _newline "4. Linking CRSP PERMNOs to Compustat GVKEYs..."

// Merge with CCM link table
merge m:m permno using "${processed}/ccm_link_clean.dta", keep(match master)

// Keep only valid links for the announcement date
keep if event_announce_date >= linkdt & event_announce_date <= linkenddt

// If multiple links exist, keep the primary one
gsort permno deal_id -linkprim linkdt
by permno deal_id: keep if _n == 1

drop _merge linkdt linkenddt linktype linkprim

display as text "After CCM linking: `c(N)' deals with GVKEYs"

/*------------------------------------------------------------------------------
5. Merge with Compustat Data
------------------------------------------------------------------------------*/

display as text _newline "5. Merging with Compustat accounting data..."

// Merge with Compustat data
merge m:m gvkey using "${processed}/compustat_annual_clean.dta", keep(match master)

// Keep only accounting data from fiscal years before or at announcement year
keep if fyear <= announce_year

// For each deal, keep the most recent fiscal year data before announcement
gsort permno deal_id gvkey -fyear
by permno deal_id gvkey: keep if _n == 1

drop _merge

display as text "After Compustat merge: `c(N)' deals with accounting data"

/*------------------------------------------------------------------------------
6. Create Accounting Variables
------------------------------------------------------------------------------*/

display as text _newline "6. Creating accounting variables..."

// Total debt (long-term debt + debt in current liabilities)
gen total_debt = lt + dlc
replace total_debt = lt if missing(dlc)
replace total_debt = dlc if missing(lt)
replace total_debt = 0 if missing(total_debt)

// Return on Assets (ROA)
gen roa = ni / at
label var roa "Return on Assets (NI/AT)"

// Leverage ratio
gen leverage = total_debt / at
label var leverage "Leverage (Total Debt/AT)"

// Sales growth (requires lagged sales)
sort gvkey fyear
by gvkey: gen sales_growth = (sale / sale[_n-1]) - 1
label var sales_growth "Sales growth rate"

// Log of total assets
gen log_assets = ln(at)
label var log_assets "Log of total assets"

// Market-to-book ratio (if market data available)
gen market_to_book = mkvalt / ceq if !missing(mkvalt) & !missing(ceq) & ceq > 0
label var market_to_book "Market-to-book ratio"

// Cash ratio
gen cash_ratio = che / at if !missing(che)
label var cash_ratio "Cash ratio (Cash/AT)"

// Current ratio (if current assets available)
// Note: Current assets not always available in basic Compustat
// gen current_ratio = act / lct if !missing(act) & !missing(lct) & lct > 0

// Tangibility
gen tangibility = (at - intan) / at if !missing(intan)
replace tangibility = 1 if missing(intan)  // Assume all tangible if intangibles missing
label var tangibility "Asset tangibility"

/*------------------------------------------------------------------------------
7. Winsorize Variables
------------------------------------------------------------------------------*/

display as text _newline "7. Winsorizing variables at 1% and 99%..."

// Winsorize continuous variables to reduce outlier impact
local winsor_vars "roa leverage sales_growth log_assets market_to_book cash_ratio tangibility"

foreach var of local winsor_vars {
    capture winsor2 `var', replace cuts(1 99)
    if _rc != 0 {
        display as text "Warning: Could not winsorize `var'"
    }
}

/*------------------------------------------------------------------------------
8. Add Variable Labels and Final Cleanup
------------------------------------------------------------------------------*/

display as text _newline "8. Adding variable labels and final cleanup..."

// Add comprehensive variable labels
label var permno "CRSP PERMNO"
label var gvkey "Compustat GVKEY"
label var deal_id "Deal identifier"
label var event_announce_date "M&A announcement date"
label var announce_year "Announcement year"
label var fyear "Fiscal year of accounting data"
label var datadate "Fiscal year end date"
label var deal_value "Deal value (millions USD)"
label var car_window_1 "CAR [-1,+1] around announcement"
label var car_window_5 "CAR [-5,+5] around announcement"
label var car_window_10 "CAR [-10,+10] around announcement"
label var at "Total assets (Compustat)"
label var ni "Net income (Compustat)"
label var sale "Sales revenue (Compustat)"
label var total_debt "Total debt (LT + DLC)"

// Create indicator for data availability
gen has_compustat = !missing(at)
label var has_compustat "Has Compustat accounting data"

// Sort and save final dataset
sort permno event_announce_date
compress
save "${processed}/event_study_with_compustat.dta", replace

/*------------------------------------------------------------------------------
9. Summary Statistics
------------------------------------------------------------------------------*/

display as text _newline "9. Generating summary statistics..."

// Summary statistics for key variables
summarize car_window_1 car_window_5 car_window_10 deal_value ///
         roa leverage sales_growth log_assets market_to_book

// Export summary statistics
estpost summarize car_window_1 car_window_5 car_window_10 deal_value ///
                  roa leverage sales_growth log_assets market_to_book
esttab using "${summary}/compustat_summary_stats.csv", ///
    cells("mean(fmt(4)) sd(fmt(4)) min(fmt(4)) max(fmt(4)) count(fmt(0))") ///
    replace noobs nonumber

// Data availability summary
tab has_compustat
tab announce_year has_compustat

display as text _newline "=== CCM and Compustat Merge Complete ==="
display as text "Output files created:"
display as text "- ${processed}/ccm_link_clean.dta"
display as text "- ${processed}/compustat_annual_clean.dta"
display as text "- ${processed}/event_study_with_compustat.dta"
display as text "- ${summary}/compustat_summary_stats.csv"
display as text _newline "Next step: Run 03_merge_datastream.do (optional)"
display as text "Or skip to: 04_create_variables.do"
