directory_to_search = "/Users/elisemiller/R_Projects/salinas/repodocuments/text_as_datatable"
pdf_directory <- "/Users/elisemiller/R_Projects/salinas/repodocuments/documents"
filelist <- list.files(directory_to_search, recursive = T)

eisnums <- projs_not_in_done$EIS.Number

basefiles <- basename(filelist)
#only keep projects that include the EIS numbers we care about
matched_projects <- filelist[stringr::str_detect(basefiles, paste0(eisnums, collapse = "|"))]
proj_basenames <- basename(matched_projects)
