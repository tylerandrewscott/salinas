#Purpose: This file conducted the supplementary filtering prescribed in 
#salinasbox/intermediate_data/appendix_removal/!README.docx
#Then it double checked the list of lost projects that 
#matched our original criteria but did not end up in our final pdf dataset
#to make sure there were no losses of actual (properly formatted) plans
# It produces a dataframe with information on the final EIS documents identified by this process and used in our sample

#Setup: Between step2 and this step, the "done" database was hand-cleaned
#to remove pages of appendices. A few other files were also deleted, 
#as discussed in 
#salinasbox/intermediate_data/appendix_removal/!README.docx
#this led to the removal of one EIS number from the dataset due to lack of a 
#clean pdf available for the plan.

projects_all <- readRDS("salinasbox/solarwind_project_details.RDS") 
removethesenums <- projects_all$EIS.Number[
  stringr::str_detect(projects_all$EIS.Title, regex("(WITHDRAWN|PROGRAMMATIC)", ignore_case = T))]

eis_pdfs <- list.files("salinasbox/intermediate_data/appendix_removal/done")
# get just EIS numbers 
eis_numstoremove <- eis_pdfs[which(substr(eis_pdfs, 1, 8) %in% removethesenums)]
#double check this looks right
projects_all$EIS.Title[projects_all$EIS.Number %in% substr(eis_numstoremove, 1, 8)]

#move those two files to the "delete" folder
for(file in eis_numstoremove){
  file.copy(from = paste0("salinasbox/intermediate_data/appendix_removal/done/",
                          file), to = paste0("./salinasbox/intermediate_data/appendix_removal/delete/", file))
  file.remove(paste0("salinasbox/intermediate_data/appendix_removal/done/",
                     file))
  
}

#now query database again
eis_pdfs <- list.files("salinasbox/intermediate_data/appendix_removal/done")
# get just EIS numbers 
eis_pdfs_nums <- unique(substr(eis_pdfs, 1, 8))
# matches

#one of these EIS numbers is a duplicate (grapevine final 20120181) from original rds file, so there are actually only 91 projects
projects_done <- projects_all[projects_all$EIS.Number %in% eis_pdfs_nums,]

# ones that didn't make it, double check to make sure we didn't lose anything unexpectedly
projs_not_in_done <- projects_all[!projects_all$EIS.Number %in% eis_pdfs_nums,]

#let's make sure everything was filtered ok
# this uses the symbolic link "repodocuments" to the enepa_repository Box folder 
directory_to_search = "repodocuments/text_as_datatable"
pdf_directory <- "repodocuments/documents"
filelist <- list.files(directory_to_search, recursive = T)

eisnums <- projs_not_in_done$EIS.Number

basefiles <- basename(filelist)
#only keep projects that include the EIS numbers we care about
matched_projects <- filelist[stringr::str_detect(basefiles, paste0(eisnums, collapse = "|"))]
proj_basenames <- basename(matched_projects)
#these are the filenames corresponding to eis numbers that match our 
#criteria but didn't end up in our database
#it's because we only have EPA comment letters for them
#or it was a programmatic file (20130070, 20190071, 20190177, 20150120, 20160078)
#or the tracked changes file we removed (20150365)
#or the withdrawn file (20210008)
#
proj_basenames

# create list of final EIS docs used for networks, join same projects together using groups.csv (created group names for draft/final of same project)
groups <- read.csv("salinasbox/clean_data/GroupIDs.csv") %>%
  select(EIS.Number, Group.Name)
eis_networks <- projects_all %>%
  select(EIS.Number, Title, Document.Type, State, Lead.Agency) %>%
  filter(EIS.Number %in% eis_pdfs_nums) %>%
  unique() %>%
  mutate(Year = as.factor(substr(EIS.Number, 1, 4)),
                 Project.Type = case_when(grepl("solar", Title, ignore.case = T) ~ "Solar",
                                          grepl("wind", Title, ignore.case = T) ~ "Wind")) %>%
  left_join(groups)

write.csv(final_eis_networks, "salinasbox/clean_data/eis_info.csv")
