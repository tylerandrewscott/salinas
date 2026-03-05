#Purpose: We used this script to generate our project-specific dataset.
#This script finds pdfs in the repo that match the EIS numbers from step 1.
#It copies those pdfs to salinasbox, excluding any EPA comment letters

#Required setup: first set up symbolic link to Box of EPA documents
#and set up symbolic link to salinas Box as "salinasbox"

directory_to_search = "../eis_documents/enepa_repository/box_files/text_as_datatable"
pdf_directory <- "../eis_documents/enepa_repository/box_files/documents"
filelist <- list.files(directory_to_search, recursive = T)

eisnums <- read.table(file = 'salinasbox/intermediate_data/solarwind_EISnumbers_V2.txt', header = F)

basefiles <- basename(filelist)
#only keep projects that include the EIS numbers we care about
matched_projects <- filelist[stringr::str_detect(basefiles, paste0(eisnums$V1, collapse = "|"))]
proj_basenames <- basename(matched_projects)

# Filter comment letters using API metadata rather than filename heuristics.
# The metadata type == "Comment_Letter" covers all comment letters for our EIS
# numbers. Text file basenames are reconstructed from fileNameForDownload using
# the same normalizations applied when the repo was built (spaces -> _, remove
# &/(/), condense __).
doc_meta <- arrow::read_parquet('../eis_documents/enepa_repository/metadata/eis_document_record_api.parquet')
comment_letters <- doc_meta[doc_meta$type == 'Comment_Letter' &
                              doc_meta$ceqNumber %in% eisnums$V1, ]
cl_stems <- tools::file_path_sans_ext(comment_letters$fileNameForDownload)
cl_stems <- gsub(" ", "_", cl_stems)
cl_stems <- gsub("[&)(]", "", cl_stems)
cl_stems <- gsub("_{2,}", "_", cl_stems)
cl_basenames <- paste0(comment_letters$ceqNumber, "_", cl_stems, ".txt")

matched_projects <- matched_projects[!proj_basenames %in% cl_basenames]
proj_basenames   <- basename(matched_projects)

proj_basenames <- stringr::str_remove(proj_basenames, ".txt$")

### note that when these files are saved, I removed all "&" and ")" or "(" characters from the file names
proj_basenames <- str_remove_all(proj_basenames,'\\&|\\)|\\(')
### likewise, all double + "__" are condensed to "_"
proj_basenames <- str_replace_all(proj_basenames,"_{2,}","_")


pdfs <- paste0(pdf_directory, "/", dirname(matched_projects), "/", proj_basenames, ".pdf")
failedfiles <- vector(mode = "character")

for(i in pdfs) {
  if(file.exists(i)){
    #print(paste0("File ", i, "exists"))
    file.copy(from = i, to = paste0("salinasbox/intermediate_data/pdfs_before_appendix_removal/", basename(i)))
  }else{
    failedfiles <- append(failedfiles, i)
    print(paste0("File ", i, "does not exist"))
  }
}


#this part is in case any files fail because they weren't found
length(failedfiles)
failedfiles <- stringr::str_remove(failedfiles, "../eis_documents/enepa_repository/documents/")
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

