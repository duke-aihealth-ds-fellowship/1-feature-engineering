################################################################################
# Adapted from online source 
# This script will take the online mapping file CCS_services_procedures_v2022-1_052422,
# clean it up into long format (each row represents 1 CPT code, corresponding to a CCS-CPT category),
# and save as cpt_ccs_mapping_v2022-1.
# AH 2023/7/28
################################################################################

library(tidyverse)
library(data.table)
library(stringr)


mapping <- fread("CCS_Services_Procedures_v2022/CCS_services_procedures_v2022-1_052422.csv")
colnames(mapping) <- c("Range", "Class", "Label")

CPT_NoLetters <- function(data){
  ########## Clean Data
  ## Subset data to only contain ranges without letters
  noletters <- data[!(grep("[A-Z]+", Range))]
  
  ## Remove single quote
  noletters[, Range := gsub("'", "", Range)]
  
  ## Split Range into Start and End
  noletters[, c("Start", "End") := tstrsplit(Range, "-", fixed=TRUE)]
  
  ## Convert class to numeric
  noletters[, Start := as.numeric(Start)][, End := as.numeric(End)]
  
  ########## Set up writing out
  ## Create new table to write codes to
  output <- data.table(Code=rep(0,100000), Class=rep(0,100000), Label=rep("empty",100000))
  
  ## Set line in output to write to
  out_line <- 1L
  
  ########## Read through every line in data set
  for(i in 1:nrow(noletters)){
    ## Calculate the number of times to repeat rows
    Reps <- (noletters[i,End] - noletters[i,Start] + 1)
    
    ## And loop through to write new lines for each code
    for(j in 1:Reps){
      ## The j index writes (Reps) new rows, where the value in the code column of each incremental row increases by 1
      set(output,out_line + (j - 1L),1L, noletters[i,Start] + (j - 1L))
      set(output,out_line + (j - 1L),2L, noletters[i,Class])
      set(output,out_line + (j - 1L),3L, noletters[i,Label])
    }
    ## Bump up the line to print from by the number of Replicate rows written
    out_line <- as.integer(out_line + Reps)
  }
  
  ########## Append leading zeros
  ## Keep output that contains data
  output <- output[Code != 0]
  
  ## Convert code to a strong
  output[, Code := as.character(Code)]
  
  ## Count number of leading zeros to insert
  output[, Leading_Zeros := as.integer(5 - nchar(Code))]
  
  ## Fill leading zeros in Code column for the rows that require it 
  for (i in which(output$Leading_Zeros != 0))
    set(output, i, 1L, paste(c(rep("0", times = output[i, Leading_Zeros]), output[i, Code]), collapse = ""))
  
  ## Drop leading zeros column
  output[, Leading_Zeros := NULL]
  
  ########## Return output that contains data
  return(output)
}
CPT_Letters <- function(data){
  ########## Clean data
  ## Subset data to only contain ranges without letters
  withletters <- data[grep("[A-Z]+", Range)]
  
  ## Remove single quote
  withletters[, Range := gsub("'", "", Range)]
  
  ## Pull letter at beginning of line
  withletters[grep("^[A-Z]", Range), At_Start := substr(Range, 1, 1)]
  
  ## Pull letter at end of line
  withletters[grep("[A-Z]$", Range), At_End := str_sub(Range, -1)]
  
  ## Remove letters from range
  withletters[, Range := gsub("[A-Z]", "", Range)]
  
  ## Split Range into Start and End
  withletters[, c("Start", "End") := tstrsplit(Range, "-", fixed=TRUE)]
  
  ## Convert class to numeric
  withletters[, Start := as.numeric(Start)][, End := as.numeric(End)]
  
  ########## Set up writing out
  ## Create new table to write codes to
  output <- data.table(Code=rep(0,100000), Class=rep(0,100000), Label=rep("empty",100000), At_Start = rep("empty",100000), At_End = rep("empty",100000))
  
  ## Set line in output to write to
  out_line <- 1L
  
  ########## Read through every line in data set
  for(i in 1:nrow(withletters)){
    ## Calculate the number of times to repeat rows
    Reps <- (withletters[i,End] - withletters[i,Start] + 1)
    
    ## And loop through to write new lines for each code
    for(j in 1:Reps){
      ## The j index writes (Reps) new rows, where the value in the code column of each incremental row increases by 1
      set(output,out_line + (j - 1L),1L, withletters[i,Start] + (j - 1L))
      set(output,out_line + (j - 1L),2L, withletters[i,Class])
      set(output,out_line + (j - 1L),3L, withletters[i,Label])
      set(output,out_line + (j - 1L),4L, withletters[i,At_Start])
      set(output,out_line + (j - 1L),5L, withletters[i,At_End])
    }
    ## Bump up the line to print from by the number of Replicate rows written
    out_line <- as.integer(out_line + Reps)
  }
  
  ########## Drop output without data
  output <- output[Code != 0]
  
  ########## Append leading zeros
  ## Convert code back to string
  output[, Code := as.character(Code)]
  
  ## Count number of leading zeros to insert
  output[, Leading_Zeros := as.integer(4 - nchar(Code))]
  
  ## Fill leading zeros in Code column for the rows that require it 
  for (i in which(output$Leading_Zeros != 0))
    set(output, i, 1L, paste(c(rep("0", times = output[i, Leading_Zeros]), output[i, Code]), collapse = ""))
  
  ########## Replace letter at beginning or end
  ## Add letter at end
  output[!is.na(At_End), Code := paste(Code, At_End, sep = "")]
  
  ## Add letter at start
  output[!is.na(At_Start), Code := paste(At_Start, Code, sep = "")]
  
  ########## Remove extra columns
  output[, c("At_Start", "At_End", "Leading_Zeros") := NULL]
  
  ## Return output
  return(output)
}

cpt2ccs <- rbind(CPT_NoLetters(mapping), CPT_Letters(mapping))

cpt2ccs <- rbindlist(list(
  data.table(Code = "", Class = 0, Label = "No label"),
  cpt2ccs
))

colnames(cpt2ccs) <- c("CPT CODE", "CCS CATEGORY", "CCS DESCRIPTION")

fwrite(cpt2ccs, "cpt_ccs_mapping_v2022-1.csv",
       row.names = FALSE)
