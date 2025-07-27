#!/usr/bin/env python3
"""
CUSIP Cleaning and Standardization Script
Standardizes CUSIP format for reliable merging in event studies
"""

import pandas as pd
import sys
import re

def clean_cusip(cusip_str):
    """Clean and standardize a single CUSIP"""
    if pd.isna(cusip_str) or cusip_str == '':
        return None
    
    cusip_str = str(cusip_str).strip().upper()
    cusip_str = re.sub(r'[^A-Z0-9]', '', cusip_str)
    
    if len(cusip_str) < 6:
        return None
    
    if len(cusip_str) == 6:
        cusip_str = cusip_str + '00'
    elif len(cusip_str) == 7:
        cusip_str = cusip_str + '0'
    elif len(cusip_str) == 8:
        pass
    elif len(cusip_str) == 9:
        cusip_str = cusip_str[:8]
    else:
        cusip_str = cusip_str[:8]
    
    return cusip_str

def clean_cusip_file(input_file, output_file):
    """Clean CUSIPs in a CSV file"""
    try:
        df = pd.read_csv(input_file)
        
        if 'cusip' in df.columns:
            df['cusip_clean'] = df['cusip'].apply(clean_cusip)
            df = df.dropna(subset=['cusip_clean'])
            df = df.drop_duplicates(subset=['cusip_clean'])
            
            print(f"Processed {len(df)} records with clean CUSIPs")
        else:
            print("No 'cusip' column found in input file")
            return False
        
        df.to_csv(output_file, index=False)
        print(f"Clean CUSIP file saved to: {output_file}")
        return True
        
    except Exception as e:
        print(f"Error processing CUSIP file: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python cusip_cleaner.py <input_file> <output_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    success = clean_cusip_file(input_file, output_file)
    if not success:
        sys.exit(1)
