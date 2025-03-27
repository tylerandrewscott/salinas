
myfiles <- list.files("salinasbox/clean_data/pdf_to_text_clean")
eis_nums <- unique(substr(myfiles, 1, 8))
mytexts <- vector(mode = "list", length = length(eis_nums))
names(mytexts) <- eis_nums
#squish individual rds files into full project text
filenum = 1
for(i in 1:length(mytexts)){
  mytexts[[i]] <- readRDS(paste0(
    "salinasbox/clean_data/pdf_to_text_clean/", myfiles[filenum]))$text
  filenum = filenum + 1
  while(filenum <= length(myfiles) & substr(myfiles[filenum], 1, 8) == eis_nums[i]){
    mytexts[[i]] <- append(mytexts[[i]], 
                           readRDS(paste0(
                             "salinasbox/clean_data/pdf_to_text_clean/", 
                             myfiles[filenum]))$text)
    filenum = filenum + 1
  }
}

myacronyms <- lapply(mytexts, function(i) find_acronyms(i))
saveRDS(myacronyms, "salinasbox/intermediate_data/project_specific_acronyms.RDS")
