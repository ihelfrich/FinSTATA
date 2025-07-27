# Event Study Templates

This directory contains templates for common event study scenarios. Each template demonstrates how to use the comprehensive event study toolkit for specific types of corporate events.

## Available Templates

### 1. COVID-19 Events Template (`covid_events_template.do`)
- **Purpose**: Analyze COVID-19 related corporate events
- **Key Features**:
  - Time-varying effects during pandemic periods
  - Cross-border deal analysis during crisis
  - Market volatility considerations
  - Pre/during/post COVID comparisons

### 2. M&A Events Template (`ma_events_template.do`)
- **Purpose**: Analyze merger and acquisition announcements
- **Key Features**:
  - Deal size and type analysis
  - Cross-border vs domestic deals
  - Target firm characteristics
  - Deal premium effects (if available)

### 3. Earnings Announcements Template (`earnings_template.do`)
- **Purpose**: Analyze quarterly earnings announcements
- **Key Features**:
  - Seasonal effects analysis
  - Quarterly comparison
  - Earnings surprise effects (if available)
  - Firm size interactions

## How to Use Templates

1. **Copy the template**: Copy the relevant template to your working directory
2. **Modify paths**: Update the working directory path at the top of the script
3. **Adapt variables**: Modify variable names and calculations based on your specific dataset
4. **Run the analysis**: Execute the template script in Stata

## Template Structure

Each template follows this general structure:

1. **Setup and Configuration**: Load the toolkit and set parameters
2. **Data Import**: Use the standard import process
3. **Event-Specific Variables**: Create variables specific to the event type
4. **Specialized Analysis**: Run analysis tailored to the event type
5. **Results Export**: Generate event-specific outputs

## Customization Guidelines

### Variable Adaptation
- Review the variable creation sections and adapt to your data structure
- Modify interaction terms based on your research questions
- Add industry or time controls as needed

### Analysis Modification
- Adjust regression specifications for your hypotheses
- Modify event windows based on your event type
- Add robustness tests specific to your research design

### Output Customization
- Modify table titles and column names
- Add event-specific visualizations
- Create custom summary statistics

## Best Practices

1. **Start with the closest template**: Choose the template that most closely matches your event type
2. **Understand the data structure**: Examine your dataset before running the template
3. **Test incrementally**: Run sections of the template to ensure they work with your data
4. **Document changes**: Keep track of modifications you make for reproducibility
5. **Validate results**: Check that results make economic sense for your event type

## Creating New Templates

To create a new template for a different event type:

1. Start with the basic toolkit structure (`00_setup.do` through `06_export_results.do`)
2. Identify event-specific variables and calculations needed
3. Create specialized analysis sections for your event type
4. Add appropriate robustness tests and subsample analysis
5. Document the template with clear comments and usage instructions

## Support

For questions about using or modifying templates:
- Review the main toolkit documentation in the repository README
- Examine the core `.do` files to understand the underlying methodology
- Check the helper scripts for data preparation guidance
