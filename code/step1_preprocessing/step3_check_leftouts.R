#Purpose: This file double checks the list of lost projects that 
#matched our original criteria but did not end up in our final pdf dataset
#This is because the only files available for these lost projects were
#EPA comment letters, which we are not using. 

#Set-up: run projectlists_databases.R to generate projs_not_in_done file

directory_to_search = "/Users/elisemiller/R_Projects/salinas/repodocuments/text_as_datatable"
pdf_directory <- "/Users/elisemiller/R_Projects/salinas/repodocuments/documents"
filelist <- list.files(directory_to_search, recursive = T)

projs_not_in_done <- readRDS("salinasbox/intermediate_data/appendix_removal/projs_not_in_done.RDS")

eisnums <- projs_not_in_done$EIS.Number

basefiles <- basename(filelist)
#only keep projects that include the EIS numbers we care about
matched_projects <- filelist[stringr::str_detect(basefiles, paste0(eisnums, collapse = "|"))]
proj_basenames <- basename(matched_projects)
#these are the filenames corresponding to eis numbers that match our 
#criteria but didn't end up in our database
#it's because we only have EPA comment letters for them
proj_basenames