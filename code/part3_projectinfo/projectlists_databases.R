# solar and wind project metadata 
projects_all <- readRDS("salinasbox/solarwind_project_details.RDS")
projects <- projects_all[,c("EIS.Number", "EIS.Title", "Document.Type", "State", "Federal.Register.Date")] 
# get wind or solar project type
projects$Project.Type <- ifelse(grepl("solar", projects$EIS.Title, ignore.case = T), "Solar", "other")
projects$Project.Type <- ifelse(grepl("wind", projects$EIS.Title, ignore.case = T), "Wind", projects$Project.Type)
# sort by type, state, name to bring related projects together
projects <- projects[order(projects$Project.Type, projects$State, projects$EIS.Title, projects$EIS.Number),]
# now filter for ones we will use in our analysis
eis_pdfs <- list.files("salinasbox/intermediate_data/appendix_removal/done")
# get just EIS numbers 
eis_pdfs_nums <- unique(substr(eis_pdfs, 1, 8))
# matches
projects_done <- projects[projects$EIS.Number %in% eis_pdfs_nums,]
projects_done <- projects_done[!duplicated(projects_done),]

EIS_file <- "salinasbox/intermediate_data/project_databases/EISlist.csv"
write.csv(projects_done, EIS_file, row.names = FALSE)

# consolidate wind turbine database by unique name and year because these will be combined into polygons 
# manually removed some columns when first downloading data, in "processing" folder
wind_projs <- read.csv("salinasbox/intermediate_data/project_databases/processing/wind_projects_smaller.csv")
# remove dupes to get single case IDs to make matching easier
wind_projs <- wind_projs[!duplicated(wind_projs[c("p_name", "p_year")]),]
wind_projs <- wind_projs[c("case_id", "t_state", "t_county", "p_name", "p_year")]
# order by state, proj name, etc. to group potentially same projects together
wind_projs <- wind_projs[order(wind_projs$t_state, wind_projs$t_county, wind_projs$p_name, wind_projs$p_year),]
write.csv(wind_projs, "salinasbox/intermediate_data/project_databases/USWTDB.csv", row.names = F)

# order solar to group potentially same projects together
solar_projs <- read.csv("salinasbox/intermediate_data/project_databases/processing/pv_projects_smaller.csv")
solar_projs <- solar_projs[,-c(6:7)]
solar_projs <- solar_projs[order(solar_projs$p_state, solar_projs$p_county, solar_projs$p_name, solar_projs$p_year),]
write.csv(solar_projs, "salinasbox/intermediate_data/project_databases/USPVDB.csv", row.names = F)

