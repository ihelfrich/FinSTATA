/*==============================================================================
Comprehensive Event Study Toolkit: Setup Script
================================================================================

Purpose: Set up working directory, Stata settings, and global paths for the 
         comprehensive event study analysis pipeline. This toolkit supports
         various types of event studies including M&A, earnings, policy changes,
         COVID-19 impacts, and custom corporate events.

Author: Comprehensive Event Study Toolkit
Date: Created for academic and professional event study analysis

Notes: 
- Run this script first before executing any other analysis scripts
- Modify the global paths below to match your local directory structure
- Installs required Stata packages if not already available
- Supports flexible event study configurations

==============================================================================*/

clear all
set more off
set linesize 120
capture log close

// Set working directory (modify this path as needed)
cd "`c(pwd)'"
global main_dir "`c(pwd)'"

// Define global paths for data and output directories
global raw_data     "${main_dir}/data/raw"
global processed    "${main_dir}/data/processed" 
global do_files     "${main_dir}/do_files"
global helpers      "${main_dir}/helpers"
global outputs      "${main_dir}/outputs"
global summary      "${outputs}/summary_stats"
global regression   "${outputs}/regression_results"

// Create directories if they don't exist
capture mkdir "${raw_data}"
capture mkdir "${processed}"
capture mkdir "${outputs}"
capture mkdir "${summary}"
capture mkdir "${regression}"

// Display directory structure
display as text _newline "=== Event Study Toolkit Setup ==="
display as text "Main directory: ${main_dir}"
display as text "Raw data: ${raw_data}"
display as text "Processed data: ${processed}"
display as text "Outputs: ${outputs}"
display as text _newline

// Check for required Stata packages and install if missing
local packages "estout winsor2 reghdfe ftools"
foreach pkg of local packages {
    capture which `pkg'
    if _rc != 0 {
        display as text "Installing `pkg'..."
        ssc install `pkg', replace
    }
    else {
        display as text "`pkg' already installed"
    }
}

// Set Stata preferences for analysis
set seed 12345
set matsize 800
set maxvar 32000

// Display system information
display as text _newline "=== System Information ==="
display as text "Stata version: `c(stata_version)'"
display as text "Current date: `c(current_date)'"
display as text "Current time: `c(current_time)'"
display as text "Memory: `c(memory)' KB"
display as text _newline

// Log file setup
local logfile "${outputs}/event_study_log_`c(current_date)'.log"
log using "`logfile'", replace text
display as text "Log file created: `logfile'"

// Define global settings for event study analysis
global event_windows "-10 -5 -1 0 1 5 10"  // Default event windows
global min_observations 30                   // Minimum observations for estimation
global estimation_period 250                 // Days for market model estimation
global gap_period 10                        // Gap between estimation and event window

display as text _newline "=== Event Study Configuration ==="
display as text "Event windows: ${event_windows}"
display as text "Minimum observations: ${min_observations}"
display as text "Estimation period: ${estimation_period} days"
display as text "Gap period: ${gap_period} days"

display as text _newline "=== Setup Complete ==="
display as text "Ready to run comprehensive event study analysis pipeline"
display as text "Next step: Run 01_import_data.do"
display as text _newline
