#!/usr/bin/env python3
"""
Dataset Structure Examination Script
Analyzes the covidevent.dta file to understand its structure and variables
"""

import pandas as pd
import sys
import os

def examine_stata_file(filepath):
    """Examine a Stata .dta file and print comprehensive information about its structure"""
    try:
        print("=== Loading Stata File ===")
        df = pd.read_stata(filepath)
        
        print(f"File: {filepath}")
        print(f"Successfully loaded dataset")
        print()
        
        print("=== Dataset Overview ===")
        print(f"Shape: {df.shape[0]:,} rows × {df.shape[1]} columns")
        print()
        
        print("=== Column Names ===")
        for i, col in enumerate(df.columns, 1):
            print(f"{i:2d}. {col}")
        print()
        
        print("=== Data Types ===")
        for col, dtype in df.dtypes.items():
            print(f"{col:<20} {dtype}")
        print()
        
        print("=== Missing Values ===")
        missing = df.isnull().sum()
        missing_pct = (missing / len(df) * 100).round(2)
        for col in df.columns:
            if missing[col] > 0:
                print(f"{col:<20} {missing[col]:>6,} ({missing_pct[col]:>5.1f}%)")
        print()
        
        print("=== Sample Data (First 5 Rows) ===")
        pd.set_option('display.max_columns', None)
        pd.set_option('display.width', None)
        print(df.head())
        print()
        
        print("=== Summary Statistics ===")
        numeric_cols = df.select_dtypes(include=['number']).columns
        if len(numeric_cols) > 0:
            print(df[numeric_cols].describe())
        else:
            print("No numeric columns found")
        print()
        
        print("=== Unique Values in Key Columns ===")
        potential_id_cols = [col for col in df.columns if any(x in col.lower() for x in ['id', 'permno', 'gvkey', 'cusip', 'ticker', 'symbol'])]
        potential_date_cols = [col for col in df.columns if any(x in col.lower() for x in ['date', 'time', 'year', 'month', 'day'])]
        
        for col in potential_id_cols[:5]:
            unique_count = df[col].nunique()
            print(f"{col:<20} {unique_count:>6,} unique values")
            
        for col in potential_date_cols[:5]:
            unique_count = df[col].nunique()
            print(f"{col:<20} {unique_count:>6,} unique values")
            if df[col].dtype == 'object':
                print(f"  Sample values: {list(df[col].dropna().unique()[:3])}")
        print()
        
        print("=== Potential Event Study Variables ===")
        event_vars = [col for col in df.columns if any(x in col.lower() for x in 
                     ['ret', 'return', 'price', 'prc', 'event', 'announce', 'car', 'ar', 'abnormal'])]
        
        if event_vars:
            print("Found potential event study variables:")
            for var in event_vars:
                print(f"  - {var}")
                if df[var].dtype in ['float64', 'int64']:
                    print(f"    Range: {df[var].min():.4f} to {df[var].max():.4f}")
                    print(f"    Mean: {df[var].mean():.4f}, Std: {df[var].std():.4f}")
        else:
            print("No obvious event study variables found")
        print()
        
        output_file = "data/processed/dataset_structure_summary.txt"
        with open(output_file, 'w') as f:
            f.write(f"Dataset Structure Summary\n")
            f.write(f"========================\n\n")
            f.write(f"File: {filepath}\n")
            f.write(f"Shape: {df.shape[0]:,} rows × {df.shape[1]} columns\n\n")
            f.write(f"Columns:\n")
            for i, col in enumerate(df.columns, 1):
                f.write(f"{i:2d}. {col} ({df[col].dtype})\n")
            f.write(f"\nPotential Event Study Variables:\n")
            for var in event_vars:
                f.write(f"  - {var}\n")
        
        print(f"Summary saved to: {output_file}")
        
        return True
        
    except Exception as e:
        print(f"Error reading Stata file: {e}")
        return False

if __name__ == "__main__":
    filepath = "data/raw/covidevent.dta"
    if not os.path.exists(filepath):
        print(f"Error: File {filepath} not found")
        sys.exit(1)
    
    success = examine_stata_file(filepath)
    if not success:
        sys.exit(1)
