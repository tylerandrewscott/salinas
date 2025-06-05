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
EIS_descriptives_all <- EIS_info %>%
  select(c(doc_type, lead_agency, state, year, project_type)) %>%
  pivot_longer(everything(),
               names_to = "variable", values_to = "value") %>%
  group_by(variable, value) %>%
  summarise(n = n()) %>%
  mutate(p = n/sum(n)) %>%
  ungroup() 

# can just use gtsummary to make table
library(gtsummary)
library(gt)

table <- tbl_summary(
  projects,
  include = c(doc_type, lead_agency, state, year),
  by = project_type,
  label = list(doc_type = "Document Type", 
               lead_agency = "Lead Agency",
               state = "State",
               year = "Year")) %>%
  add_overall() %>%
  modify_header(label ~ "**Document Attribute**") %>%
  modify_spanning_header(c("stat_1", "stat_2") ~ "Renewable Project Type")

table
gtsave(as_gt(table), "salinasbox/presentations_and_outputs/doc_sample_table.html")

########## plots showing document distributions
library(ggplot2)

# single plots per attribute
attributes <- unique(EIS_descriptives$variable)
plots <- lapply(attributes, function(attr) {
  attribute <- EIS_descriptives %>%
    filter(variable == paste0(attr))
  plot <- ggplot(attribute, aes(x = value, y = n)) +
    geom_col(fill = "antiquewhite4") +
    labs(x = NULL, y = "Count", title = paste0("number of plans by ", attr)) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))  
  return(plot)
})

# plots colored by project type


  ggplot(projects, aes(x = year, fill = project_type)) +
    geom_bar()+
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  


ggplot(EIS_descriptives, aes(x = value, y = n)) +
  geom_bar(stat = "identity", fill = "antiquewhite4") +
  facet_wrap(~ variable, scales = "free_x") +
  labs(x = NULL, y = "Count", title = "distribution of EIS attributes") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))



