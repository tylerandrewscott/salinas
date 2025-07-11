# match case_ids 
library(tidyr)
library(sf)

wind_multi <- st_read("salinasbox/intermediate_data/project_databases/wind_multipoint.gpkg")
# expand wind project case IDs back out but now each case ID corresponds to entire project multipoint geom
wind_multi_long <- wind_multi %>%
  separate_longer_delim(cols = project_caseIDs, delim = ", ") %>%
  rename(case_id = project_caseIDs, geometry = geom) %>%
  st_set_geometry("geometry")

solar_polys <- st_read("salinasbox/intermediate_data/project_databases/solar_polys.shp") %>%
  select(case_id, p_name, p_year, geometry) 

# st_crs(wind_multi_long) == st_crs(solar_polys)

#combine wind and solar
wind_solar <- bind_rows(wind_multi_long, solar_polys) %>%
  st_as_sf()

# match to EIS found case IDs
EIS_caseIDs <- read.csv("salinasbox/intermediate_data/project_databases/found_caseIDs_may22.csv") %>%
  select(c(EIS.Number, EIS.Title, Document.Type, Project.Type, Case.ID)) %>%
  separate_longer_delim(cols = Case.ID, delim = ", ") %>%
# split when multiple caseIDs found for one EIS
  filter(!is.na(EIS.Number))

matched_caseIDs <- left_join(EIS_caseIDs, wind_solar, by = join_by(Case.ID == case_id)) %>%
  select(EIS.Number, Document.Type, Project.Type, EIS.Title, p_name, p_year, Case.ID, geometry)

### NEED TO CHECK THESE, SOME ARE NOT OBVIOUS MATCHES

# as .gpkg because multipoint
st_write(matched_caseIDs, "salinasbox/intermediate_data/project_databases/matched_caseIDs.gpkg")
