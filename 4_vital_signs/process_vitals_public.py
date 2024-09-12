# This script processes raw vitals (from CRDM) to select the entries before certain encounter date.
import pandas as pd
import numpy as np
import sys, os
MAIN_DIR = 'xxx'
DATA_DIR = os.path.join(MAIN_DIR, 'crdm')
OUT_DIR  = os.path.join(MAIN_DIR, 'processed')

print('Loading Vitals')

ALL_COLUMNS = [
    'VITALID', 'PATID', 'ENCOUNTERID',
    'MEASURE_DATE', 'MEASURE_TIME', 'VITAL_SOURCE',
    'HT','WT','DIASTOLIC','SYSTOLIC','ORIGINAL_BMI','BP_POSITION',
    'SMOKING','TOBACCO','TOBACCO_TYPE','RAW_DIASTOLIC','RAW_SYSTOLIC',
    'RAW_BP_POSITION','RAW_SMOKING','RAW_TOBACCO','RAW_TOBACCO_TYPE'
]

USE_COLUMNS = [
    'PATID',
    'MEASURE_DATE',
    'DIASTOLIC',
    'SYSTOLIC',
    'HT',
    'WT',
    'ORIGINAL_BMI',
#    'Body Surface Area',
#    'Temperature in Centigrade',
#    'Pulse in Beats per Minute',
#    'Pulse Oximetry',
#    'Respiration',
#    'Peak Expiratory Flow Rate',
#    'Level of Pain',
#    'Head Circumference in Centimeters' # don't have all these
]
vitals = pd.read_csv(os.path.join(DATA_DIR, 'vital.csv'), usecols=USE_COLUMNS)

print('Merging Age and Saving')

frame = vitals
frame = frame.merge(pt[['PATID','BIRTH_DATE','ENC_DATE']], how='left')
frame['Age in Days'] = (pd.to_datetime(frame['MEASURE_DATE']) - pd.to_datetime(frame['BIRTH_DATE'])).dt.days
# only keep vitals on/before well-child encounter
frame = frame[frame['MEASURE_DATE'] <= frame['ENC_DATE']]