# === ENVIRONMENT SETUP - MUST BE FIRST ===                                                                              
# cuda_path <- "/cvmfs/hpc.ucdavis.edu/sw/spack/environments/core/view/generic/cuda-12.3.0"                                
# 
# 

overwrite <- T
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

files <- list.files(path = "salinasbox/clean_data/pdf_to_text_clean",
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

parse_fileloc <- paste0("salinasbox/intermediate_data/parsed_files/", basename(files))                                   

# ---------------------------------------------------------------------------
# Load dictionaries
# ---------------------------------------------------------------------------
library(jsonlite)

salinasbox <- file.path('salinasbox')

# 1. Acronym/abbreviation dictionary (filtered)
acronym_raw <- jsonlite::fromJSON(
  file.path(salinasbox, "intermediate_data/dictionaries/acronym_dictionary_filtered.json"),
  simplifyVector = FALSE
)

# Universal: exactly one expansion across all docs
# Ambiguous: multiple expansions (e.g. "Applicant" = different entity per project)
acronym_universal <- Filter(function(x) x$n_expansions == 1, acronym_raw)
acronym_ambiguous <- Filter(function(x) x$n_expansions > 1, acronym_raw)

# All expansion names for the entity ruler (universal + ambiguous)
acronym_universal_names <- sapply(acronym_universal, function(x) x$expansions[[1]]$expansion)
acronym_ambiguous_names <- unlist(lapply(acronym_ambiguous, function(x)
  sapply(x$expansions, function(e) e$expansion)
))

# Ambiguous dict saved for post-hoc disambiguation — not used by entity ruler
ambiguous_dict <- lapply(acronym_ambiguous, function(x) {
  list(
    term       = x$term,
    expansions = lapply(x$expansions, function(e) list(
      expansion   = e$expansion,
      ceq_numbers = unique(sub("_.*", "", e$sources)),
      sources     = e$sources
    ))
  )
})
names(ambiguous_dict) <- sapply(acronym_ambiguous, function(x) x$term)

# 2. Preparers/consultees (all universal — each name is an org, no ambiguity)
preparers_raw <- jsonlite::fromJSON(
  file.path(salinasbox, "intermediate_data/dictionaries/preparers_consultees.json")
)
preparers_names <- preparers_raw$name

# 3. Glossary terms — 2+ word n-grams only (for named entity recognition)
glossary_raw <- jsonlite::fromJSON(
  file.path(salinasbox, "intermediate_data/dictionaries/glossary_dictionary.json")
)
glossary_names <- glossary_raw$term[stringr::str_count(glossary_raw$term, "\\s+") >= 1]

# ---------------------------------------------------------------------------
# Build universal dictionary
# ---------------------------------------------------------------------------
universal_names <- unique(c(acronym_universal_names, acronym_ambiguous_names, preparers_names, glossary_names))
universal_names <- universal_names[!grepl(":", universal_names)]
universal_names <- universal_names[!sapply(universal_names, PeriodicTable::isSymb, USE.NAMES = FALSE)]

dict_ents <- entity_specify(universal_names, case_sensitive = T,
                            whole_word_only = T, entity_label = "DICT")

# append structural patterns (label = "PATTERN")
dict_ents <- c(dict_ents, textNet::build_structural_org_patterns())                                     

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
parsed_files <- list.files("salinasbox/intermediate_data/parsed_files", pattern = "\\.parquet$", full.names = TRUE)
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
                  "PARTIES", "CUSTOM", "DICT", "PATTERN")                                                                                             

dir.create("salinasbox/intermediate_data/raw_extracted_networks")
for(m in 1:length(projects)){
  extract_file <- paste0("salinasbox/intermediate_data/raw_extracted_networks/extract_", names(projects)[m], "_V2.RDS")     
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

saveRDS(object = extracts, file = "salinasbox/intermediate_data/raw_extracts_V2.RDS")
