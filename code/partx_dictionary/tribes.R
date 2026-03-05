library(tigris)
library(tidyverse)
library(sf)

# this is not perfect and doesn't have the most specific names, but has names of tribes associated with tribal areas determined by the census
native_areas <- native_areas() %>%
  select(NAME, NAMELSAD) %>%
  st_drop_geometry() %>%
  rename(tribe = NAME, reservation = NAMELSAD)

# use tribal leaders csv from https://catalog.data.gov/dataset/tribal-leaders-directory-14ff5/resource/878159f4-8947-4339-9b49-3e3484349fa5
tribal_leaders <- read_csv("salinasbox/dictionary_data/tribal-leaders.csv")
tribe_names <- tribal_leaders %>%
  rename(tribe_full_name = `Tribe Full Name`, tribe = Tribe, tribe_alt_names = `Tribe Alternate Name`) %>%
  select(tribe_full_name, tribe, tribe_alt_names)

full_tribes <- full_join(native_areas, tribe_names) %>%
  unique()

write.csv(full_tribes, "salinasbox/dictionary_data/tribes.csv")

