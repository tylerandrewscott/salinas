# === ENVIRONMENT SETUP - MUST BE FIRST ===                                                                              
# cuda_path <- "/cvmfs/hpc.ucdavis.edu/sw/spack/environments/core/view/generic/cuda-12.3.0"                                
# 
# 

overwrite <- F                                                                                                                                                                                               
test <- T                                                                                                                                                                                                    

library(textNet)                                                                                                                                                                                             
library(spacyr)                                                                                                                                                                                              
library(stringr)                                                                                                                                                                                             

ret_path <- "/home/tscott1/.conda/envs/textnet/bin/python"      

# Purpose: This script takes the text files we cleaned in part 1,                                                        
# and runs spaCy on them to identify named entities and                                                                  
# token dependencies for network generation                                                                              
# then it takes those spacy outputs and groups them by EIS number                                                        
# and runs textnet extract to generate the network files for each plan                                                   
# those extracts are saved in intermediate_files                                                                         
# Setup: requires textNet, spaCy, python                                                                                 
# if you want to overwrite file outputs, set overwrite to T                                                              

files <- list.files(path = "salinasbox/clean_data/pdf_to_text_clean",                                                    
                    pattern = ".RDS", full.names = T)                                                                    

texts <- lapply(files, function(i){                                                                                      
  readRDS(i)$text                                                                                                        
})                                                                                                                       
names(texts) <- basename(files)                                                                                          

parties <- c("Project", "Projects",                                                                                      
             "Applicant", "Applicants",                                                                                  
             "Permittee", "Permittees",                                                                                  
             "Proponent", "Proponents",                                                                                  
             "Band", "Bands",                                                                                            
             "tribe", "tribes",                                                                                          
             "Tribe", "Tribes",                                                                                          
             "we", "We")                                                                                                 

parse_fileloc <- paste0("salinasbox/intermediate_data/parsed_files/", basename(files))                                   

ets <- read.csv('salinasbox/dictionary_data/test_entities.csv', header = F)                                              
ets <- ets[!grepl('\\:', ets$V2), ]                                                                                      

dict_ents <- entity_specify(unique(ets$V2), case_sensitive = T, whole_word_only = T)                                     

# === RUN PARSING ===                                                                                                    
parsed <- textNet::parse_text(ret_path,                                                                                  
                              text_list = texts[1],                                                                      
                              parsed_filenames = parse_fileloc,                                                          
                              overwrite = overwrite,                                                                     
                              test = test,                                                                               
                              use_gpu = 'gpu',                                                                           
                              model = "en_core_web_trf",                                                                 
                              entity_ruler_patterns = dict_ents,                                                         
                              overwrite_ents = T,                                                                        
                              ruler_position = 'after',                                                                  
                              custom_entities = list(PARTIES = parties))                                                 

names(parsed) <- names(texts)                                                                                            
saveRDS(object = parsed, file = "salinasbox/intermediate_data/all_parsed.RDS")                                           

# === GROUP BY EIS NUMBER ===                                                                                            
projects <- vector(mode = "list", length = length(unique(substr(basename(files), 1, 8))))                                
names(projects) <- unique(substr(basename(files), 1, 8))                                                                 

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
                  "PARTIES")                                                                                             

for(m in 1:length(projects)){                                                                                            
  extract_file <- paste0("salinasbox/intermediate_data/raw_extracted_networks/extract_", names(projects)[m], ".RDS")     
  if(overwrite == T | !file.exists(extract_file)){                                                                       
    extracts[[m]] <- textnet_extract(projects[[m]],                                                                      
                                     cl = 4,                                                                             
                                     keep_entities = keptentities,                                                       
                                     return_to_memory = T,                                                               
                                     keep_incomplete_edges = T,                                                          
                                     file = extract_file)                                                                
  } else {                                                                                                               
    print(paste0("file ", extract_file, " already exists."))                                                             
  }                                                                                                                      
}                                                                                                                        

saveRDS(object = extracts, file = "salinasbox/intermediate_data/raw_extracts.RDS")