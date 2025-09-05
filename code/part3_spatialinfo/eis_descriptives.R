library(dplyr)
library(tidyr)
################################## variable descriptives ###########################

projects <- read.csv("salinasbox/intermediate_data/project_databases/EISlist.csv")
projects$year <- as.character(projects$year) # to join different classes
# create region groups and year groups
projects <- projects %>%
  mutate(region = case_when(
      state %in% c("CA", "NV", "AZ", "NM", "UT", "CO", "WY", "MT", "ID", "WA", "OR", "AK", "HI") ~ "West",
      state %in% c("ND", "SD", "NE", "KS", "IA", "MN", "MO") ~ "Midwest",
      state %in% c("WI", "IL", "IN", "OH", "MI") ~ "Midwest",
      state %in% c("NY", "PA", "NJ", "MA", "CT", "RI", "VT", "NH", "ME", "MD", "DC", "DE") ~ "Northeast",
      state %in% c("VA", "WV", "KY", "TN", "NC", "SC", "GA", "FL", "AL", "MS", "LA", "AR", "OK", "TX") ~ "South",
      state == "Multi" ~ "Multi-state",
      TRUE ~ "Other/Unknown"
    ),
    year_group = case_when(
      year %in% c("2012", "2013", "2014", "2015") ~ "2012–2015",
      year %in% c("2016", "2017", "2018", "2019") ~ "2016–2019",
      year %in% c("2020", "2021", "2022", "2023") ~ "2020–2023",
      TRUE ~ "Other/Unknown"
    )
  )

var_descriptives_grouped <- projects_grouped %>%
  select(doc_type, lead_agency, region, year_group, project_type) %>%
  pivot_longer(everything(), names_to = "Variable", values_to = "Category") %>%
  group_by(Variable, Category) %>%
  summarise(Count = n()) %>%
  mutate(Percentage = paste0(round(Count / sum(Count) * 100, 1), "%")) 

var_descriptives_all <- projects %>%
  select(doc_type, lead_agency, state, year, project_type) %>%
  pivot_longer(everything(), names_to = "Variable", values_to = "Category") %>%
  group_by(Variable, Category) %>%
  summarise(Count = n()) %>%
  mutate(Percentage = paste0(round(Count / sum(Count) * 100, 1), "%")) 

# breakdown by wind and solar 
projects_summary <- projects %>%
  pivot_longer(cols = c(doc_type, lead_agency, region, state, year, year_group),
               names_to = "Variable",
               values_to = "Level") %>%
  group_by(Variable, Level, project_type) %>%
  summarise(Count = n(), .groups = "drop") %>%
  group_by(Variable) %>%
  mutate(Percent = round(Count / sum(Count) * 100, 1)) %>%
  mutate(Count_Percent = paste0(Count, " (", Percent, "%)")) %>%
  select(Variable, Level, project_type, Count_Percent) %>%
  pivot_wider(names_from = project_type, values_from = Count_Percent) %>%
  ungroup()

# add overall column
projects_overall <- projects %>%
  pivot_longer(cols = c(doc_type, lead_agency, region, state, year, year_group),
               names_to = "Variable",
               values_to = "Level") %>%
  group_by(Variable, Level) %>%
  summarise(Count = n(), .groups = "drop") %>%
  group_by(Variable) %>%
  mutate(Percent = round(Count / sum(Count) * 100, 1)) %>%
  mutate(Overall = paste0(Count, " (", Percent, "%)")) %>%
  select(Variable, Level, Overall)

# combine wind/solar with overall column
projects_summary_final <- left_join(projects_summary, projects_overall,
                                    by = c("Variable", "Level")) %>%
  arrange(Variable, Level)


# can just use gtsummary to make table
library(gtsummary)
library(gt)
# probably will want to bin years and maybe do something about states too
table <- tbl_summary(
  projects,
  include = c(doc_type, lead_agency, region, state, year, year_group),
  by = project_type,
  label = list(doc_type = "Document Type", 
               lead_agency = "Lead Agency",
               region = "Region",
               year_group = "Year Range")) %>%
  add_overall() %>%
  modify_header(label ~ "**Document Attribute**") %>%
  modify_spanning_header(c("stat_1", "stat_2") ~ "Renewable Project Type")

# group states and years?

table
gtsave(as_gt(table), "salinasbox/presentations_and_outputs/doc_sample_table.png")

########## plots showing document distributions
library(ggplot2)

# single plots per attribute
attributes <- unique(var_descriptives$Variable)
plots <- lapply(attributes, function(attr) {
  attribute <- var_descriptives %>%
    filter(Variable == paste0(attr))
  plot <- ggplot(attribute, aes(x = Category, y = Count)) +
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



