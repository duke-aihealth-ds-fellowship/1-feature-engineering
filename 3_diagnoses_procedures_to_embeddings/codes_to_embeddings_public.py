# This script converts a long format codes (eg. diagnosis, procedures, 1 code per line) into embeddings
# output file with PATID, EMB_0, ..., EMB_255 (1 patient per line)
# test_patids is optional. It is used to exclude a list of patients from the embedding training set to avoid leakage
# Created by Angel Huang 6/2024

import pandas as pd
import numpy as np
import sys, os
import pickle
from gensim.models import Word2Vec
from multiprocessing import cpu_count

MAIN_DIR = 'xxx'
RAW_DATA_DIR = os.path.join(MAIN_DIR, 'raw')
EMB_DATA_DIR = os.path.join(RAW_DATA_DIR, 'embedding','duke_first2years_codes.csv') 
TEST_ID_DIR = os.path.join(RAW_DATA_DIR, 'test_id','Raw-Test-Data_ASD-Duke.csv')
PROCESSED_DATA_DIR = os.path.join(MAIN_DIR, 'processed')

def update_embeddings(X_long, embeddings, test_patids=[], output_dir=None):
# The goal of this function is to remove test set patients from embedding dataset to avoid contamination!
    print('Convert codes into embeddings...')
    # Some testing
    test_embeddings = embeddings[embeddings['PATID'].isin(test_patids)]
    #print(len(test_embeddings)) 
    #print(len(test_patids)) # 1798 total test_patids
    print('Remove ' + str(len(test_embeddings['PATID'].unique())) + '/' + str(len(embeddings['PATID'].unique())) + ' PATIDs from embedding training') 
    
    # remove test set patients from embedding dataset to avoid contamination!
    embedding_filtered = embeddings[~embeddings['PATID'].isin(test_patids)]
    # Sort the dataframe by PATID and codes_date
    embedding_filtered = embedding_filtered.sort_values(['PATID', 'age'])

    # Load w2v if already existing
    w2v_file = output_dir + '/word2vec.pickle'
    if os.path.exists(w2v_file):
        # Load the existing model
        w2v = pickle.load(open(w2v_file,'rb'))
        print("Existing Word2Vec model loaded.")        
    else:
        # Otherwise train a word2vec model
        # 1. aggregate each patient's history into a list, sentences are list of list
        print("Training Word2Vec model.")
        sentences = embedding_filtered.groupby("PATID").agg({"value": list})["value"].to_list()
        # 2. train word2vec
        w2v = Word2Vec(min_count=0,
                         window=3,
                         vector_size=256,
                         sample=6e-5, 
                         alpha=0.01, 
                         min_alpha=0.0001, 
                         negative=20,
                         workers=cpu_count() - 1)
        w2v.build_vocab(sentences)
        w2v.train(sentences, total_examples=w2v.corpus_count, epochs=30)
        # Save word2vec
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
        pickle.dump(w2v, open(w2v_file,'wb'))
        print('Saving trained w2v.')
    
    # 3. load raw dx px data, 1 row per dx
    # Convert DX code to embedding (automatically generate 256 columns) 1min
    all_patient_dx = []
    for _, patient in X_long.groupby("PATID"):
        events = []
        for event in patient["codes"]:
            if event in w2v.wv: # I have ICD9 codes that doesn't exist in embedding code, skip them since I will average them later
                embedding = w2v.wv[event]
                events.append(embedding)
        if events:        
            patient_history_embedding = np.array(events).mean(axis=0) # average across all events for a patient, get 1x256

            # Create DataFrame for this patient 
            patient_dx = pd.DataFrame({'PATID': [patient['PATID'].iloc[0]]})
            # Join embedding columns
            patient_dx = patient_dx.join(pd.DataFrame(patient_history_embedding).T)
             # Append to final DataFrame
            all_patient_dx.append(patient_dx)
        
    # rename columns from numbers to EMB_x
    combined_dx = pd.concat(all_patient_dx)
    for col in combined_dx.columns:
        if col != 'PATID': # don't change name of PATID
            combined_dx = combined_dx.rename(columns={col: 'EMB_' + str(col)}) # other columns add prefix
    combined_dx = combined_dx.set_index('PATID')
        
    X_embed = combined_dx
    # Save to csv
    print('Saving trained X_embed.')
    X_embed.to_csv(output_dir + '/X_embed.csv', index=True)    
    return X_embed

# loading dataset for generating embedded dataset
embeddings = pd.read_csv(EMB_DATA_DIR, dtype={'PATID': str})
embeddings = embeddings[~embeddings['value'].isna()] 
test_patids = pd.read_csv(TEST_ID_DIR, dtype={'PATID': str}, usecols=['PATID'])['PATID'].unique().tolist() # exclude ids

codes = pd.read_csv(PROCESSED_DATA_DIR + '/dx_px.csv', dtype={'PATID': str}) # X_long
X_embed = update_embeddings(codes, embeddings, test_patids, PROCESSED_DATA_DIR)

