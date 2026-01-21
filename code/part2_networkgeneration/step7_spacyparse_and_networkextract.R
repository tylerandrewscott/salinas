#Purpose: This script takes the text files we cleaned in part 1,
#and runs spaCy on them to identify named entities and
#token dependencies for network generation
#then it takes those spacy outputs and groups them by EIS number
#and runs textnet extract to generate the network files for each plan
#those extracts are saved in intermediate_files

#Setup: requires textNet, spaCy, python, and (recommended) findpython
#if you want to overwrite file outputs, set overwrite to T
#(we shouldn't need to do this unless changes made to network generation process)

overwrite = F
test = T
library(textNet)
library(findpython)
#spacy_parse() takes a named list where 
#each element is a different file. 
#let's set it up
files <- list.files(path = "salinasbox/clean_data/pdf_to_text_clean", 
           pattern = ".RDS", full.names = T)

texts <- vector(mode = "list", length = 
                     length(files))

texts <- lapply(files, function(i){
  readRDS(i)$text
})

names(texts) <- basename(files)

# to resolve issues with finding python binary with find_python
library(reticulate)
myenv <- conda_list(conda = "auto")$python
use_condaenv(myenv[4])

ret_path <- find_python_cmd(required_modules = c('spacy', 'en_core_web_lg','en_core_web_trf'))

parties <- c("Project", "Projects",
             "Applicant", "Applicants",
             "Permittee", "Permittees",
             "Proponent", "Proponents",
             "Band", "Bands",
             "tribe", "tribes",
             "Tribe", "Tribes",
             "we", "We")

#where we want to save these parsed dataframes:
parse_fileloc <- paste0("salinasbox/intermediate_data/parsed_files/", basename(files))


ets <- read.csv('salinasbox/dictionary_data/test_entities.csv',header = F)
ets <- ets[!grepl('\\:',ets$V2),]
library(stringr)

dict_ents <- entity_specify(unique(ets$V2),case_sensitive = T,whole_word_only = T)

parsed <- textNet::parse_text(ret_path,
                              text_list = texts[1:2],
                              parsed_filenames = parse_fileloc,
                              overwrite = overwrite,
                              ##### test = T forces run
                              ##### otherwise, if file already exists, will load
                              test = test,
                              #### will use gpu on FARM ###
                              use_gpu = 'auto',
                              ### NEW THING I CHANGED MODEL ####
                              model = "en_core_web_trf",
                              ### add entityrulers ###
                              entity_ruler_patterns = dict_ents,
                              ### override if NER gaps a entityruler object ###
                              overwrite_ents = T,
                              ### entityruler has final say ### 
                              ruler_position = 'after'
                              custom_entities = list(PARTIES = parties))

names(parsed) <- names(texts)
saveRDS(object = parsed, file = "salinasbox/intermediate_data/all_parsed.RDS")

#put all parts of same eis number together

projects <- vector(mode = "list", length = 
                     length(unique(substr(basename(files), 1, 8))))

names(projects) <- unique(substr(basename(files), 1, 8))

filenum = 1
for(i in 1:length(projects)){
  projects[[i]] <- parsed[[filenum]]
  filenum = filenum + 1
  while(filenum <= length(parsed) & substr(names(parsed)[filenum], 1, 8) == names(projects)[i]){
    projects[[i]] <- rbind(projects[[i]], parsed[[filenum]])
    filenum = filenum + 1
  }
}

extracts <- vector(mode = "list", length = length(projects))
#better to be inclusive with entity types and remove later
#see link below, page 21 for definitions
#https://catalog.ldc.upenn.edu/docs/LDC2013T19/OntoNotes-Release-5.0.pdf

#"EVENT" doesn't have much in it but we will preserve just in case
#"LANGUAGE" doesn't have much in it but sometimes "Latino" (??)
#did not keep "MONEY" because it appeared unreliable (sometimes was kJ, etc.)
keptentities <- c("PERSON", 
              "NORP", 
              "FAC",
              "ORG", "GPE", 
              "LOC", "PRODUCT", 
              "EVENT", "WORK_OF_ART",
              "LAW", "LANGUAGE",
              "PARTIES")
for(m in 1:length(projects)){
  if(overwrite ==T | !file.exists(paste0("salinasbox/intermediate_data/raw_extracted_networks/extract_", names(projects)[m],".RDS"))){
    extracts[[m]] <- textnet_extract(projects[[m]], 
                                     cl = 4,
                                     keep_entities = keptentities,
                                     return_to_memory = T,
                                     keep_incomplete_edges = T,
                                     file = paste0("salinasbox/intermediate_data/raw_extracted_networks/extract_", names(projects)[m],".RDS")
    )
  }else{
    print(paste0("file ", paste0("salinasbox/intermediate_data/raw_extracted_networks/extract_", names(projects)[m],".RDS"),
                 " already exists."))
  }
  
}
saveRDS(object = extracts, file = "salinasbox/intermediate_data/raw_extracts.RDS")



