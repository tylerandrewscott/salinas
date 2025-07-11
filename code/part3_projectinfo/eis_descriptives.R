library(dplyr)
library(tidyr)
################################## variable descriptives ###########################

projects <- read.csv("salinasbox/intermediate_data/project_databases/EISlist.csv")
projects$year <- as.character(projects$year) # to join different classes
EIS_descriptives <- projects %>%
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
# probably will want to bin years and maybe do something about states too
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

# group states and years?

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
plots[[5]]


# plots colored by project type

ggplot(projects, aes(x = year, fill = project_type)) +
  geom_bar()+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggplot(projects, aes(x = lead_agency, fill = project_type)) +
  geom_bar()+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggplot(projects, aes(x = doc_type, fill = project_type)) +
  geom_bar()+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggplot(projects, aes(x = state, fill = project_type)) +
  geom_bar()+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggplot(EIS_descriptives, aes(x = value, y = n)) +
  geom_bar(stat = "identity", fill = "antiquewhite4") +
  facet_wrap(~ variable, scales = "free_x") +
  labs(x = NULL, y = "Count", title = "distribution of EIS attributes") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))



