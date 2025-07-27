# Comprehensive Event Study Toolkit

A modular, production-grade toolkit for conducting event studies across various types of corporate events using financial market data. This toolkit is designed to be flexible and adaptable to different event study scenarios including M&A announcements, earnings releases, policy changes, COVID-19 impacts, and other corporate events.

## Overview

This repository provides a complete pipeline to:
- Import and clean event data and stock returns
- Define flexible event windows around any type of corporate event
- Calculate abnormal returns (AR) and cumulative abnormal returns (CAR)
- Merge with accounting and firm characteristic data
- Run statistical tests and cross-sectional regressions
- Export comprehensive results and visualizations
- Handle various data formats and event types

## Supported Event Types

The toolkit is designed to handle various event study scenarios:
- **M&A Announcements**: Merger and acquisition events
- **Earnings Announcements**: Quarterly and annual earnings releases
- **Policy Changes**: Regulatory and policy announcements
- **COVID-19 Events**: Pandemic-related corporate events
- **Product Launches**: New product or service announcements
- **Management Changes**: CEO and executive appointments
- **Custom Events**: Any user-defined corporate events

## Data Requirements

The toolkit is flexible and can work with various data sources:
- **Stock Returns Data**: Daily or monthly returns (CRSP, Yahoo Finance, etc.)
- **Event Data**: Event dates and characteristics in CSV or Stata format
- **Firm Characteristics**: Accounting data (Compustat, hand-collected, etc.)
- **Market Data**: Market indices and risk-free rates
- **Optional Data**: Industry classifications, analyst data, etc.

## Repository Structure

```
event-study-crsp-compustat/
├── README.md
├── data/
│   ├── raw/              # Place all original data files here
│   └── processed/        # Store all cleaned and merged datasets here
├── do_files/
│   ├── 00_setup.do                    # Environment setup and configuration
│   ├── 01_import_data.do              # Data import and initial cleaning
│   ├── 02_define_events.do            # Event window definition and preparation
│   ├── 03_calculate_returns.do        # Return calculations and market models
│   ├── 04_create_variables.do         # Variable creation and transformations
│   ├── 05_run_analysis.do             # Statistical tests and regressions
│   └── 06_export_results.do           # Results export and visualization
├── helpers/
│   ├── examine_dataset.py             # Dataset structure analysis
│   ├── cusip_cleaner.py              # CUSIP standardization
│   └── data_validator.py             # Data quality checks
├── templates/
│   ├── ma_events_template.do         # M&A event study template
│   ├── earnings_template.do          # Earnings announcement template
│   └── covid_events_template.do      # COVID-19 event template
└── outputs/
    ├── summary_stats/
    ├── regression_results/
    └── plots/
```

## Installation & Setup

### Stata Requirements
- Stata 15 or higher recommended
- Required packages: `estout`, `winsor2`, `reghdfe` (install via `ssc install`)

### Python Requirements (for helper scripts)
```bash
pip install pandas numpy matplotlib seaborn
```

## Quick Start Guide

### Step 1: Examine Your Data
```bash
# First, examine your dataset structure
python helpers/examine_dataset.py
```

### Step 2: Data Preparation
1. Place your event data file in `data/raw/`
2. Ensure your data includes:
   - Firm identifiers (PERMNO, GVKEY, ticker, etc.)
   - Event dates
   - Stock returns or prices
   - Any firm characteristics

### Step 3: Run Analysis Pipeline

Execute the Stata scripts in order:

```stata
// Set up environment and paths
do "do_files/00_setup.do"

// Import and clean your data
do "do_files/01_import_data.do"

// Define event windows
do "do_files/02_define_events.do"

// Calculate abnormal returns
do "do_files/03_calculate_returns.do"

// Create additional variables
do "do_files/04_create_variables.do"

// Run statistical analysis
do "do_files/05_run_analysis.do"

// Export results
do "do_files/06_export_results.do"
```

### Step 4: Review Results
- Summary statistics: `outputs/summary_stats/`
- Regression results: `outputs/regression_results/`
- Plots and visualizations: `outputs/plots/`
- Final datasets: `data/processed/`

## Using Templates

For common event study types, use the provided templates:

```stata
// For M&A events
do "templates/ma_events_template.do"

// For earnings announcements
do "templates/earnings_template.do"

// For COVID-19 events
do "templates/covid_events_template.do"
```

## Key Features

### Flexible Event Definition
- Customizable event windows (e.g., [-1,+1], [-5,+5], [-10,+10] days)
- Multiple event types supported
- Handles overlapping events and clustering

### Return Calculations
- Market model abnormal returns
- Market-adjusted returns
- Size and book-to-market adjusted returns
- Buy-and-hold abnormal returns (BHAR)

### Statistical Testing
- Parametric and non-parametric significance tests
- Cross-sectional regression analysis
- Time-series aggregation tests
- Robust standard errors and clustering

### Variable Creation
- **Financial Ratios**: ROA, ROE, leverage, liquidity ratios
- **Growth Measures**: Sales growth, asset growth, market growth
- **Size Variables**: Market cap, total assets, sales
- **Industry Controls**: SIC-based industry classifications
- **Event Characteristics**: Deal size, payment method, etc.

### Output Generation
- Comprehensive summary statistics
- Event study plots and visualizations
- Regression tables in multiple formats
- Publication-ready results

## File Descriptions

### Core Stata Scripts
- `00_setup.do`: Environment setup, package installation, and global configurations
- `01_import_data.do`: Data import, cleaning, and initial preparation
- `02_define_events.do`: Event window definition and event data preparation
- `03_calculate_returns.do`: Return calculations, market models, and abnormal returns
- `04_create_variables.do`: Variable creation, transformations, and labeling
- `05_run_analysis.do`: Statistical tests, regressions, and significance testing
- `06_export_results.do`: Results export, tables, and visualization

### Python Helpers
- `examine_dataset.py`: Analyzes dataset structure and variables
- `cusip_cleaner.py`: Standardizes CUSIP format for reliable merging
- `data_validator.py`: Performs data quality checks and validation

### Templates
- `ma_events_template.do`: Complete M&A event study workflow
- `earnings_template.do`: Earnings announcement event study
- `covid_events_template.do`: COVID-19 event impact analysis

## Methodology Notes

- Follows academic best practices for event study methodology
- Implements multiple abnormal return calculation methods
- Handles various statistical testing approaches
- Accounts for clustering and cross-sectional dependence
- Provides robust standard error calculations

## Customization

The toolkit is designed to be easily customizable:
- Modify event windows in `02_define_events.do`
- Add custom variables in `04_create_variables.do`
- Implement different return models in `03_calculate_returns.do`
- Customize output formats in `06_export_results.do`

## Citation

If you use this toolkit in academic research, please cite appropriately and follow your institution's guidelines for reproducible research.

## Support

For questions, issues, or contributions:
- Review the extensive documentation within each script
- Check the templates for common use cases
- Examine the helper scripts for data preparation guidance
