# solar and wind projects from EIS salinas folder
url <- "https://github.com/tylerandrewscott/salinas/raw/refs/heads/main/solarwind_project_details.RDS"
projects_all <- readRDS(url(url, method = "libcurl"))
projects <- projects_all[,c("EIS.Title", "Document.Type", "State", "Federal.Register.Date")]
# get wind or solar project type
projects$Type <- ifelse(grepl("solar", projects$EIS.Title, ignore.case = T), "Solar", "other")
projects$Type <- ifelse(grepl("wind", projects$EIS.Title, ignore.case = T), "Wind", projects$Type)
# add empty columns to fill in with info from solar/wind databases
projects$Project.Name <- NA
projects$Database <- NA
# sort alphabetically, by state, and by type
projects <- projects[order(projects$Type, projects$State, projects$EIS.Title),]
# save csv to box
write.csv(projects,"salinasbox/intermediate_data/project_databases/projectlist.csv")

