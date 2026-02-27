# === ENVIRONMENT SETUP - MUST BE FIRST ===                                                                              
# cuda_path <- "/cvmfs/hpc.ucdavis.edu/sw/spack/environments/core/view/generic/cuda-12.3.0"                                
# 
# 

overwrite <- F
test <- F

source("code/config.R")
if (OVERWRITE_ALL) overwrite <- TRUE
library(textNet)                                                                                                                                                                                             
library(spacyr)                                                                                                                                                                                              
library(stringr)                                                                                                                                                                                             


#ret_path <- "/home/tscott1/.conda/envs/textnet/bin/python"      
ret_path <- grep('spacy-env',reticulate::conda_list()$python,value = T)

# Purpose: This script takes the text files we cleaned in part 1,                                                        
# and runs spaCy on them to identify named entities and                                                                  
# token dependencies for network generation                                                                              
# then it takes those spacy outputs and groups them by EIS number                                                        
# and runs textnet extract to generate the network files for each plan                                                   
# those extracts are saved in intermediate_files                                                                         
# Setup: requires textNet, spaCy, python                                                                                 
# if you want to overwrite file outputs, set overwrite to T                                                              

files <- list.files(path = paste0("salinasbox/clean_data/pdf_to_text_clean", app_suffix),
                    pattern = ".RDS", full.names = T)                                                                    

texts <- lapply(files, function(i){
  tmp <- readRDS(i)$text
  tmp <- str_replace_all(tmp,'\\n',' ')
  tmp <- tmp[!is.na(tmp)&nchar(tmp)>200]
  tmp
})
names(texts) <- basename(files)

# remove files with no usable text to keep texts and parse_fileloc aligned
# (parse_text_trf skips empty texts but doesn't skip the corresponding filename)
empty_texts <- sapply(texts, length) == 0
if (any(empty_texts)) {
  message("Removing ", sum(empty_texts), " file(s) with no text >200 chars: ",
          paste(basename(files[empty_texts]), collapse = ", "))
  files <- files[!empty_texts]
  texts <- texts[!empty_texts]
}

parties <- c("Project", "Projects",
             "Applicant", "Applicants",
             "Permittee", "Permittees",
             "Proponent", "Proponents",
             "Band", "Bands",
             "tribe", "tribes",
             "Tribe", "Tribes",
             "we", "We")

parse_fileloc <- paste0("salinasbox/intermediate_data/parsed_files", app_suffix, "/", basename(files))                                   

ets <- read.csv('salinasbox/dictionary_data/final_acronym_dictionary.csv', header = T)         

ets <- ets[!grepl('\\:', ets$name), ] 
ets <- ets[!sapply(ets$acronym,PeriodicTable::isSymb),]
ets$clean <- stringr::str_replace_all(ets$name,'_',' ')

dict_ents <- entity_specify(unique(ets$clean), case_sensitive = T, whole_word_only = T)                                     

# === RUN PARSING ===                                                                                                    
parsed <- textNet::parse_text_trf(ret_path,                                                                                  
                                  text_list = texts,                                                                      
                                  parsed_filenames = parse_fileloc,                                                          
                                  overwrite = overwrite,                                                                     
                                  test = test,                                                               
                                  entity_ruler_patterns = dict_ents,                                                         
                                  overwrite_ents = T,                                                                        
                                  ruler_position = 'after',                                                                  
                                  custom_entities = list(PARTIES = parties))                                                 

# === GROUP BY EIS NUMBER ===
# Load all parsed docs from parquet (saved by parse_text_trf)
parsed_files <- list.files(paste0("salinasbox/intermediate_data/parsed_files", app_suffix), pattern = "\\.parquet$", full.names = TRUE)
parsed <- lapply(parsed_files, textNet::read_parsed_trf)
names(parsed) <- basename(parsed_files)

projects <- vector(mode = "list", length = length(unique(substr(basename(parsed_files), 1, 8))))
names(projects) <- unique(substr(basename(parsed_files), 1, 8))

filenum <- 1
for(i in 1:length(projects)){
  projects[[i]] <- parsed[[filenum]]
  filenum <- filenum + 1
  while(filenum <= length(parsed) & substr(names(parsed)[filenum], 1, 8) == names(projects)[i]){
    projects[[i]] <- rbind(projects[[i]], parsed[[filenum]])
    filenum <- filenum + 1
  }
}                                                                                                                        

# === EXTRACT NETWORKS ===                                                                                               
extracts <- vector(mode = "list", length = length(projects))                                                             

keptentities <- c("PERSON",                                                                                              
                  "NORP",                                                                                                
                  "FAC",                                                                                                 
                  "ORG", "GPE",                                                                                          
                  "LOC", "PRODUCT",                                                                                      
                  "EVENT", "WORK_OF_ART",                                                                                
                  "LAW", "LANGUAGE",                                                                                     
                  "PARTIES",'CUSTOM')                                                                                             

dir.create(paste0("salinasbox/intermediate_data/raw_extracted_networks", app_suffix))
for(m in 1:length(projects)){                                                                                            
  extract_file <- paste0("salinasbox/intermediate_data/raw_extracted_networks", app_suffix, "/extract_", names(projects)[m], "_V2.RDS")     
  if(overwrite == T | !file.exists(extract_file)){                                                                       
    extracts[[m]] <- textnet_extract(projects[[m]],                                                                      
                                     cl = 1,                                                                             
                                     keep_entities = keptentities,                                                       
                                     return_to_memory = T,                                                               
                                     keep_incomplete_edges = T,                                                          
                                     file = extract_file)                                                                
  } else {                                                                                                               
    print(paste0("file ", extract_file, " already exists."))                                                             
  }                                                                                                                      
}                                                                                                                        

saveRDS(object = extracts, file = paste0("salinasbox/intermediate_data/raw_extracts_V2", app_suffix, ".RDS"))
