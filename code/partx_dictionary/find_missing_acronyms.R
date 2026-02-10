library(tidyverse)
acronym_table <- readRDS("salinasbox/intermediate_data/partial_acronym_list_from_table_only.RDS")
# find which plans do not have acronym list 
plans <- as.data.frame(names(acronym_table))
rows <- lapply(acronym_table, nrow)
plans$aclist <- unlist(rows)
missing <- plans %>%
  filter(aclist < 15)

write_csv(missing, "salinasbox/dictionary_data/missing_from_acronym_function.csv")
# note that some of these are still missing some, but i can't tell why they would have been missed based on elise's code


### manually got missing acroynms, adding to those elise found

# get found acronyms to merge 
full <- bind_rows(acronym_table, .id = "plan")
found <- read_csv("salinasbox/dictionary_data/found_additional_acronyms.csv")

found_ <- found %>%
  mutate(across(c(name, acronym), ~str_replace_all(.x, " ", "_"))) %>%
  mutate(plan = as.character(plan))

final_entities <- bind_rows(full, found_) %>%
  unique(.)
 
write_csv(final_entities, "salinasbox/dictionary_data/final_acronym_dictionary.csv")

