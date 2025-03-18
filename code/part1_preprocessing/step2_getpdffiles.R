#Purpose: We used this script to generate our project-specific dataset.
#This script finds pdfs in the repo that match the EIS numbers from step 1.
#It copies those pdfs to salinasbox, excluding any EPA comment letters and appendices

#Required setup: first set up symbolic link to Box of EPA documents as "repodocuments"
#and set up symbolic link to salinas Box as "salinasbox"

directory_to_search = "repodocuments/text_as_datatable"
pdf_directory <- "repodocuments/documents"
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
#sometimes EPA comment letters have the phrase "EPA_comments". Remove these (but recommended to check first to make sure the file doesn't say 'with EPA comments')
matched_projects <- matched_projects[!stringr::str_detect(proj_basenames, 
                                                          paste0("EPA_(C|c)omments"))]
proj_basenames <- basename(matched_projects)
#remove files that are labeled as appendices, except keep them if they say 'with' or 'and' appendix
noapps <- matched_projects[stringr::str_detect(matched_projects, "(with|and)_*(a|A)ppendi") |
  !stringr::str_detect(proj_basenames, "(A|a)ppendix|(A|a)ppendices|_App_*[A-Z]")]
proj_basenames <- basename(noapps)

#let's inspect the few documents that include "EPA" or "Comments" to see if they are comment letters:
noapps[stringr::str_detect(proj_basenames, "EPA") | stringr::str_detect(proj_basenames, "(C|c)omment")]
#EIS number 20130268 responses to comments should be removed since it is not listed in the main EIS table of contents,
#which means it's not a main plan part.
#EIS number 20200022 should be removed since it is Appendix T
#EIS number 20210038 should NOT be removed since it is a full EIS draft
#EIS numbers 20210155, 20220056, 20220084, 20220171, and 20220186 are comment letters and 
#should be removed
#this desired filtering can be achieved by keeping "forpubliccomment" and 
#removing other instances of "comment" like so:
noapps <- noapps[!stringr::str_detect(proj_basenames, "(?<!forPublic)Comment")]

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


#this part is in case any files fail because they weren't found
length(failedfiles)
failedfiles <- stringr::str_remove(failedfiles, "repodocuments/documents/")
#use this to manually search for these pdfs and manually add them to the pdfs_before_appendix_removal repo
failedfiles
#most of the time the fail is just because of parentheses in the filename or 
#there being a copy number at the end of the filename and is not truly a missing file
saveRDS(failedfiles, "salinasbox/intermediate_data/failedfiles.RDS")

failedfiles
#20130126 cover abstract is a duplicate, so we remove this
#20220084 oceanwind1 is a duplicate, so we remove this too
#a bunch of duplicates for 20160085 were removed

#the only actual failed files remaining are
#"2010/20100115_Cover_Letter_to_Jim_Abbott_7.12.10.pdf" 
#which is not a full plan anyway
#and "2011/20110443_CEQ20110443.pdf" which is also probably just a comment letter

#extra project checks to make sure these filters didn't remove anything it wasn't supposed to
matched_projects[stringr::str_detect(matched_projects, "EPA")]
matched_projects[stringr::str_detect(matched_projects, "Appendix|Appendices|_App_*[A-Z]")]

