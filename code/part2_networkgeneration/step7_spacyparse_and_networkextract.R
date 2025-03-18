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

ret_path <- find_python_cmd(required_modules = c('spacy', 'en_core_web_lg'))

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

parsed <- textNet::parse_text(ret_path,
                              text_list = texts,
                              parsed_filenames = parse_fileloc,
                              overwrite = T,
                              custom_entities = list(PARTIES = parties))
saveRDS(object = parsed, file = "parsed.RDS")
names(parsed) <- names(texts)
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
  if(overwrite ==T | !file.exists(paste0("salinasbox/intermediate_data/extracted_networks/extract_", names(projects)[m]))){
    extracts[[m]] <- textnet_extract(projects[[m]], 
                                     cl = 4,
                                     keep_entities = keptentities,
                                     return_to_memory = T,
                                     keep_incomplete_edges = T,
                                     file = paste0("salinasbox/intermediate_data/extracted_networks/extract_", names(projects)[m])
    )
  }else{
    print(paste0("file ", paste0("salinasbox/intermediate_data/extracted_networks/extract_", names(projects)[m]),
                 " already exists."))
  }
  
}



