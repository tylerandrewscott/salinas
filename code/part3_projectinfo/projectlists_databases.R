# solar and wind project metadata for eis with "wind" or "solar" in title
projects_all <- readRDS("salinasbox/solarwind_project_details.RDS")
# plans used in analysis after filtering
eis_pdfs <- list.files("salinasbox/intermediate_data/appendix_removal/done")
# get just EIS numbers 
eis_pdfs_nums <- unique(substr(eis_pdfs, 1, 8))
# get info for plans used in analysis
projects <- projects_all %>%
  select(EIS = EIS.Number, 
         title = EIS.Title, 
         doc_type = Document.Type, 
         lead_agency = Agency, 
         state = State) %>%
  filter(EIS %in% eis_pdfs_nums) %>%
  mutate(year = substr(EIS, 1, 4),
         project_type = case_when(grepl("solar", title, ignore.case = T) ~ "Solar",
                                  grepl("wind", title, ignore.case = T) ~ "Wind")) %>%
  unique() %>%
  arrange(project_type, title, state) 

EIS_file <- "salinasbox/intermediate_data/project_databases/EISlist.csv"
write.csv(projects, EIS_file, row.names = FALSE)

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

