library(sf)
library(dplyr)

geom_manual <- st_read("salinasbox/intermediate_data/project_databases/google_maps_points.gpkg") %>% 
  select(EIS.Number, geom) %>%
  mutate(geom_source = "manual")

geom_databases <- st_read("salinasbox/intermediate_data/project_databases/matched_caseIDs_polys.gpkg") %>%
  select(EIS.Number, geom) %>%
  mutate(geom_source = "uspvdb or uswtdb") 

# project google maps pts to db crs 
geom_manual <- st_transform(geom_anya, st_crs(geom_databases))

eis_info <- read.csv("salinasbox/clean_data/eis_info.csv")
eis_info_spatial <- left_join(eis_info, geom_databases)

# now only add geom_manual location if geom is empty from geom_databases


