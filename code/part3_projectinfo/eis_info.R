library(dplyr)
# solar and wind project metadata for eis with "wind" or "solar" in title
projects_all <- readRDS("salinasbox/solarwind_project_details.RDS")
# plans used in analysis after filtering
eis_pdfs <- list.files("salinasbox/intermediate_data/appendix_removal/done")
# get just EIS numbers 
eis_pdfs_nums <- unique(substr(eis_pdfs, 1, 8))
# group IDs linking same projects together
groups <- read.csv("salinasbox/clean_data/GroupIDs.csv")
# get info for plans used in analysis
projects <- projects_all %>%
  select(EIS = EIS.Number, 
         title = EIS.Title, 
         doc_type = Document.Type, 
         lead_agency = Agency, 
         state = State) %>%
  filter(EIS %in% eis_pdfs_nums) %>%
  mutate(year = as.character(substr(EIS, 1, 4)),
         project_type = case_when(grepl("solar", title, ignore.case = T) ~ "Solar",
                                  grepl("wind", title, ignore.case = T) ~ "Wind")) %>%
  unique() %>%
  arrange(project_type, title, state) %>%
  left_join(select(groups, EIS.Number, group = Group.Name), by = join_by(EIS == EIS.Number))

EIS_file <- "salinasbox/intermediate_data/project_databases/EISlist.csv"
write.csv(projects, EIS_file, row.names = FALSE)

################################## variable descriptives ###########################

EIS_info$year <- as.character(EIS_info$year) # to join different classes
EIS_descriptives <- EIS_info %>%
  select(c(doc_type, lead_agency, state, year, project_type)) %>%
  pivot_longer(everything(),
               names_to = "variable", values_to = "value") %>%
  group_by(variable, value) %>%
  summarise(n = n()) %>%
  mutate(p = n/sum(n))
