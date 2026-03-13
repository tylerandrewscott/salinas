#Purpose: Identifies the final set of EIS documents in our sample and produces
# eis_info_V2.csv. Filtering of WITHDRAWN/PROGRAMMATIC/ADOPT records and
# transmission-line exclusions happens upstream in step1.
source("code/config.R")
library(data.table)
library(tidyverse)
projects_all <- data.table(readRDS("salinasbox/solarwind_project_details_V2.RDS"))

pdf_input_dir <- "salinasbox/intermediate_data/pdfs_before_appendix_removal"

eis_pdfs <- list.files(pdf_input_dir)
eis_pdfs_nums <- unique(substr(eis_pdfs, 1, 8))


# create list of final EIS docs used for networks, join same projects together using groups.csv (created group names for draft/final of same project)
groups <- read.csv("salinasbox/clean_data/GroupIDs.csv") %>%
  #rename(ceqNumber = EIS.Number) %>%
  select(ceqNumber, Group.Name) %>%
  mutate(ceqNumber = as.character(ceqNumber))
colnames(projects_all)
eis_networks <- projects_all %>%
  select(ceqNumber, title, type, primaryState, leadAgency) %>%
  filter(ceqNumber %in% eis_pdfs_nums) %>%
  unique() %>%
  mutate(Year = as.factor(substr(ceqNumber, 1, 4)),
                 Project.Type = case_when(grepl("solar", title, ignore.case = T) ~ "Solar",
                                          grepl("wind", title, ignore.case = T) ~ "Wind")) %>%
  left_join(groups)

write.csv(eis_networks, "salinasbox/clean_data/eis_info_V2.csv", row.names = FALSE)
