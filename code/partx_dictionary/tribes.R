library(tigris)
library(dplyr)
library(sf)

# this is not perfect and doesn't have the most specific names, but has names of tribes associated with tribal areas determined by the census
native_areas <- native_areas() %>%
  select(NAME, NAMELSAD) %>%
  st_drop_geometry()
write.csv(native_areas, "salinasbox/dictionary_data/tribes.csv")
