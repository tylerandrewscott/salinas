library(tidyverse)
acronyms <- read_csv("salinasbox/intermediate_data/dictionaries/acronyms_2012_2013.csv")
ancronyms_dupes <- acronyms %>%
  mutate(Name = tolower(`Full Name`)) %>%
  group_by(Acronym) %>%
  filter(n_distinct(Name) > 1) %>%
  arrange(Acronym) %>%
  distinct(Acronym, Name, .keep_all = T) %>%
  select(c(EIS, Acronym, Name))

acronyms_unique <- acronyms %>%
  mutate(Name = tolower(`Full Name`)) %>%
  group_by(Acronym) %>%
  filter(n_distinct(Name) == 1) %>%
  arrange(Acronym) %>%
  distinct(Acronym, Name, .keep_all = T) %>%
  select(c(EIS, Acronym, Name))
