''' 
The main function of this code is to append ccs category to a dataframe that has ICD9 or ICD10 codes. 
Created by Matt
Adapted by Angel 11/9/2022
1. Changed column names and ccs_map key to match CRDM data pull
2. Add 'CCS CATEGORY UP' to map ICD before dot to capture some missing matches
'''

import numpy as np
import pandas as pd
import os

MAIN_DIR = os.path.expanduser('P:/xxx/Scripts') # Your main directory
CCS_DIR = os.path.join(MAIN_DIR, '2_prepare_features/ccs') # Your folder with mapping files


def append_ccs_dx(df, multilevel=True):
    '''adds ccs diagnoses to diagnoses dataframe df'''
    # DX_TYPE is 9 or 10, indicating ICD-9-CM or ICD-10_CM
    ccs_map = {
        '09': get_icd_ccs_dict('ccs_dx_icd9_dxref_2015.csv', 'ICD-9-CM CODE'),
        '10': get_icd_ccs_dict('ccs_dx_icd10cm_2019_1.csv', 'ICD-10-CM CODE')}

    df['CCS CATEGORY'] = [ccs_map.get(x, {}).get(y, 0) for x, y in zip(
        df['DX_TYPE'],
        df['DX'].str.replace('.', '', regex=False))]

    df['CCS CATEGORY UP'] = [ccs_map.get(x, {}).get(y, 0) for x, y in zip(
        df['DX_TYPE'],
        df['DX'].str.split('.').str[0])]

    # if can find ICD code, get CCX, else get the ICD code before the dot (higher level) to get CCX

    if multilevel:
        df = df.merge(
            get_ccs_multilevel('ccs_dx_icd10cm_2019_1.csv', 'ICD-10-CM CODE'),
            how='left')

    return df


def append_ccs_pr(df, multilevel=True):
    '''adds ccs diagnoses to problem-list dataframe df'''
    ccs_map = {
        **get_icd_ccs_dict('ccs_dx_icd9_prref_2015.csv', 'ICD-9-CM CODE'),
        **get_icd_ccs_dict('ccs_pr_icd10pcs_2019_1.csv', 'ICD-10-PCS CODE')}

    df['CCS CATEGORY'] = [ccs_map.get(x, 0) for x in df['CONDITION'].str.replace(
        '.', '', regex=False)]

    if multilevel:
        df = df.merge(
            get_ccs_multilevel('ccs_pr_icd10pcs_2019_1.csv', 'ICD-10-PCS CODE'))

    return df


def get_icd_ccs_dict(fn, icd_col_name, ccs_col_name='CCS CATEGORY'):
    '''creates dictionary mapping icd codes to ccs codes'''
    dx = load_ccs(os.path.join(CCS_DIR, fn))
    return dict_from_lists(dx[icd_col_name], dx[ccs_col_name].astype(int))


def get_ccs_multilevel(fn, icd_col_name):
    '''returns dataframe with multilevel ccs categories'''
    ccs = load_ccs(os.path.join(CCS_DIR, fn))
    ccs.drop([icd_col_name, icd_col_name + ' DESCRIPTION'], axis=1, inplace=True)
    ccs['CCS CATEGORY'] = ccs['CCS CATEGORY'].astype(int)
    ccs['MULTI CCS LVL 1'] = ccs['MULTI CCS LVL 1'].astype(int)
    ccs['MULTI CCS LVL 2'] = ccs['MULTI CCS LVL 2'].replace(
        r'^\s*$', '0.0', regex=True).str.split('.').str[-1].astype(int)
    return ccs.drop_duplicates()


def load_ccs(fn):
    '''corrects formatting of ccs lookup tables'''
    df = pd.read_csv(fn)
    df.columns = df.columns.str.strip("'").str.strip()
    df = df.apply(lambda x: x.str.strip("'").str.strip(), axis=1)
    return df


def dict_from_lists(l1, l2):
    assert len(l1) == len(l2)
    return {x: y for x, y in zip(l1, l2)}
    
