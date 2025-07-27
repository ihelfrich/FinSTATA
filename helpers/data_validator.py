#!/usr/bin/env python3
"""
Data Validation Script
Performs comprehensive data quality checks for event study datasets
"""

import pandas as pd
import numpy as np
import sys
import os
from datetime import datetime

def validate_event_study_data(filepath):
    """Validate event study dataset and report data quality issues"""
    try:
        print("=== Event Study Data Validation ===")
        df = pd.read_stata(filepath)
        
        print(f"Dataset: {filepath}")
        print(f"Shape: {df.shape[0]:,} rows × {df.shape[1]} columns")
        print()
        
        print("=== Required Variable Check ===")
        required_vars = ['firm_id', 'event_date', 'stock_return']
        missing_vars = []
        
        for var in required_vars:
            matches = [col for col in df.columns if var.lower() in col.lower()]
            if not matches:
                missing_vars.append(var)
            else:
                print(f"✓ Found {var}: {matches[0]}")
        
        if missing_vars:
            print(f"✗ Missing required variables: {missing_vars}")
        print()
        
        print("=== Date Validation ===")
        date_cols = [col for col in df.columns if 'date' in col.lower()]
        
        for col in date_cols:
            print(f"Checking {col}:")
            if df[col].dtype == 'object':
                try:
                    pd.to_datetime(df[col])
                    print(f"  ✓ String dates appear valid")
                except:
                    print(f"  ✗ Cannot parse string dates")
            else:
                print(f"  ✓ Numeric date format")
            
            missing_dates = df[col].isnull().sum()
            if missing_dates > 0:
                print(f"  ⚠ {missing_dates:,} missing dates ({missing_dates/len(df)*100:.1f}%)")
            else:
                print(f"  ✓ No missing dates")
        print()
        
        print("=== Return Data Validation ===")
        return_cols = [col for col in df.columns if any(x in col.lower() for x in ['ret', 'return']) 
                      and 'abnormal' not in col.lower()]
        
        for col in return_cols:
            print(f"Checking {col}:")
            
            missing_returns = df[col].isnull().sum()
            print(f"  Missing values: {missing_returns:,} ({missing_returns/len(df)*100:.1f}%)")
            
            if df[col].dtype in ['float64', 'int64']:
                extreme_low = (df[col] < -0.5).sum()
                extreme_high = (df[col] > 2.0).sum()
                print(f"  Extreme returns (<-50%): {extreme_low:,}")
                print(f"  Extreme returns (>200%): {extreme_high:,}")
                
                print(f"  Mean: {df[col].mean():.4f}")
                print(f"  Std Dev: {df[col].std():.4f}")
                print(f"  Range: {df[col].min():.4f} to {df[col].max():.4f}")
        print()
        
        print("=== Firm Identifier Validation ===")
        id_cols = [col for col in df.columns if any(x in col.lower() for x in ['id', 'permno', 'gvkey', 'cusip'])]
        
        for col in id_cols:
            print(f"Checking {col}:")
            unique_firms = df[col].nunique()
            total_obs = len(df)
            print(f"  Unique values: {unique_firms:,}")
            print(f"  Obs per firm (avg): {total_obs/unique_firms:.1f}")
            
            missing_ids = df[col].isnull().sum()
            if missing_ids > 0:
                print(f"  ⚠ Missing IDs: {missing_ids:,}")
            else:
                print(f"  ✓ No missing IDs")
        print()
        
        print("=== Panel Structure Validation ===")
        if len(id_cols) > 0 and len(date_cols) > 0:
            id_col = id_cols[0]
            date_col = date_cols[0]
            
            duplicates = df.duplicated(subset=[id_col, date_col]).sum()
            if duplicates > 0:
                print(f"  ⚠ Duplicate firm-date observations: {duplicates:,}")
            else:
                print(f"  ✓ No duplicate firm-date observations")
            
            ts_length = df.groupby(id_col).size()
            print(f"  Time series length - Mean: {ts_length.mean():.1f}, Median: {ts_length.median():.1f}")
            print(f"  Min length: {ts_length.min()}, Max length: {ts_length.max()}")
        print()
        
        print("=== Data Completeness Summary ===")
        missing_summary = df.isnull().sum().sort_values(ascending=False)
        missing_pct = (missing_summary / len(df) * 100).round(1)
        
        print("Variables with missing data:")
        for var, missing in missing_summary.items():
            if missing > 0:
                print(f"  {var:<20} {missing:>6,} ({missing_pct[var]:>5.1f}%)")
        
        complete_vars = (missing_summary == 0).sum()
        print(f"\nComplete variables: {complete_vars}/{len(df.columns)}")
        print()
        
        output_file = "data/processed/data_validation_report.txt"
        with open(output_file, 'w') as f:
            f.write(f"Data Validation Report\n")
            f.write(f"=====================\n\n")
            f.write(f"File: {filepath}\n")
            f.write(f"Validation Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Shape: {df.shape[0]:,} rows × {df.shape[1]} columns\n\n")
            
            f.write(f"Data Quality Summary:\n")
            f.write(f"- Complete variables: {complete_vars}/{len(df.columns)}\n")
            if len(id_cols) > 0:
                f.write(f"- Unique firms: {df[id_cols[0]].nunique():,}\n")
            if duplicates > 0:
                f.write(f"- Duplicate observations: {duplicates:,}\n")
            
            f.write(f"\nVariables with missing data:\n")
            for var, missing in missing_summary.items():
                if missing > 0:
                    f.write(f"  {var}: {missing:,} ({missing_pct[var]:.1f}%)\n")
        
        print(f"Validation report saved to: {output_file}")
        return True
        
    except Exception as e:
        print(f"Error validating data: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python data_validator.py <filepath>")
        sys.exit(1)
    
    filepath = sys.argv[1]
    if not os.path.exists(filepath):
        print(f"Error: File {filepath} not found")
        sys.exit(1)
    
    success = validate_event_study_data(filepath)
    if not success:
        sys.exit(1)
