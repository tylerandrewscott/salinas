library(data.table)
library(stringr)
myfiles <- list.files("salinasbox/clean_data/pdf_to_text_clean")
rawfiles <- list.files("salinasbox/intermediate_data/pdf_to_text_raw")

eis_nums <- unique(substr(myfiles, 1, 8))
mytexts <- vector(mode = "list", length = length(eis_nums))
rawtexts <- vector(mode = "list", length = length(eis_nums))

names(mytexts) <- eis_nums
#squish individual rds files into full project text
#we need to use rawtext version for the helper at the bottom of this script
#because tables have a lot of white space so might be cleaned out of the clean text version
filenum = 1
for(i in 1:length(mytexts)){
  mytexts[[i]] <- readRDS(paste0(
    "salinasbox/clean_data/pdf_to_text_clean/", myfiles[filenum]))$text
  rawtexts[[i]] <- fread(paste0(
    "salinasbox/intermediate_data/pdf_to_text_raw/", rawfiles[filenum]))$text
  filenum = filenum + 1
  while(filenum <= length(myfiles) & substr(myfiles[filenum], 1, 8) == eis_nums[i]){
    mytexts[[i]] <- append(mytexts[[i]], 
                           readRDS(paste0(
                             "salinasbox/clean_data/pdf_to_text_clean/", 
                             myfiles[filenum]))$text)
    rawtexts[[i]] <- append(rawtexts[[i]], 
                           fread(paste0(
                             "salinasbox/intermediate_data/pdf_to_text_raw/", 
                             rawfiles[filenum]))$text)
    filenum = filenum + 1
  }
}

#find_acronyms is to detect parenthetically defined acronyms
myacronyms <- lapply(mytexts, function(i) find_acronyms(i))

#append with acronymhelper but do not overwrite existing acronyms
#generateacronymhelper is to detect acronyms from a table of acronyms
source("code/part2_networkgeneration/helpers/generateacronymhelper.R")
for(i in 1:length(myacronyms)){
  #because myacronyms is bound first, removing duplicates will
  #prefer the acronyms that are parenthetically defined
  myacronyms[[i]] <- rbind(myacronyms[[i]], acrontable[[i]])
  #can't accept one acronym going to multiple contradicting "to" nodes, so we filter duplicates
  myacronyms[[i]] <- myacronyms[[i]][!duplicated(myacronyms[[i]]$acronym),]
}
saveRDS(myacronyms, "salinasbox/intermediate_data/project_specific_acronyms.RDS")
