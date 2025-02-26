directory_to_search = "/Users/elisemiller/R_Projects/salinas/repodocuments/text_as_datatable"
pdf_directory <- "/Users/elisemiller/R_Projects/salinas/repodocuments/documents"
filelist <- list.files(directory_to_search, recursive = T)

eisnums <- read.table(file = 'salinasbox/intermediate_data/solarwind_EISnumbers.txt', header = F)

basefiles <- basename(filelist)
#only keep projects that include the EIS numbers we care about
matched_projects <- filelist[stringr::str_detect(basefiles, paste0(eisnums$V1, collapse = "|"))]
proj_basenames <- basename(matched_projects)

#get rid of EPA comment letters, which are of the form EISnum_EISnum.txt or EISnum_EISnumtt.txt
matched_projects <- matched_projects[!stringr::str_detect(proj_basenames, 
                                                          paste0("^(", paste0(eisnums$V1, collapse = "|"), ")_", 
                                                                "(", paste0(eisnums$V1, collapse = "|"), ")(t*|_DEIS_CVOW).txt"))]
proj_basenames <- basename(matched_projects)
#sometimes EPA comment letters have the phrase "EPA_comments"
matched_projects <- matched_projects[!stringr::str_detect(proj_basenames, 
                                                          paste0("EPA_(C|c)omments"))]
proj_basenames <- basename(matched_projects)
#misses lower case appendix, but this is removed later by hand
noapps <- matched_projects[!stringr::str_detect(proj_basenames, "Appendix|Appendices|_App_*[A-Z]")]
proj_basenames <- basename(noapps)
noapps <- noapps[!stringr::str_detect(proj_basenames, "EPA") & !stringr::str_detect(proj_basenames, "(C|c)omment")]

noapps
proj_basenames <- stringr::str_remove(basename(noapps), ".txt$")
pdfs <- paste0(pdf_directory, "/", dirname(noapps), "/", proj_basenames, ".pdf")
failedfiles <- vector(mode = "character")
for(i in pdfs) {
  if(file.exists(i)){
    #print(paste0("File ", i, "exists"))
    file.copy(from = i, to = paste0("./salinasbox/intermediate_data/pdfs_before_appendix_removal/", basename(i)))
  }else{
    failedfiles <- append(failedfiles, i)
    print(paste0("File ", i, "does not exist"))
  }
}

#267 - 57 = 210 failed
# minus 51 = 159 left
failedfiles <- stringr::str_remove(failedfiles, "/Users/elisemiller/R_Projects/salinas/originalBoxpdfs/")
saveRDS(failedfiles, "salinasbox/intermediate_data/failedfiles.RDS")

failedfiles

#remove files from failedfiles that I found manually
failedfiles <- failedfiles[-c(3:15)]
failedfiles <- failedfiles[-c(3:9)]
#20130126 cover abstract is a duplicate, so we remove this too
failedfiles <- failedfiles[-c(3:21)]
failedfiles <- failedfiles[-c(166:171)]
#oceanwind1 is a duplicate, so we remove this too
failedfiles <- failedfiles[-c(141:149)]
failedfiles <- failedfiles[-c(141:156)]
failedfiles <- failedfiles[-c(124:140)]
failedfiles <- failedfiles[-c(86:123)]
failedfiles <- failedfiles[-c(30:85)]
#a bunch of duplicates for 20160085 were removed
failedfiles <- failedfiles[-c(21:29)]
failedfiles <- failedfiles[-c(3:20)]

allfailed <- readRDS("salinasbox/intermediate_data/failedfiles.RDS")

#project checks
matched_projects[stringr::str_detect(matched_projects, "EPA")]
matched_projects[stringr::str_detect(matched_projects, "(a|A)ttachment")]
matched_projects[stringr::str_detect(matched_projects, "Appendix|Appendices|_App_*[A-Z]")]
#check these
#"2016/20160085_...

#rescue pdfs that were lost with the appendix filter
matched_projects[stringr::str_detect(matched_projects, "(with|and)_*(a|A)ppendi")]
#"2022/20220056_SRC_SR_Tullahoma-Moore_Co_Solar_DEIS_20220415_EIS_with_Appendices.txt"
#"2021/20210011_North_Alabama_Utility-Scale_Solar_Draft_EIS_Body_and_Appendices.txt"
#"2012/20120323_DSEIS_Silver_State_Solar_Project_with_Appendices.txt"  

 
