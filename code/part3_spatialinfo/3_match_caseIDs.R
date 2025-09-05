# merge project-matched case_ids to their spatial data 
library(tidyr)
library(sf)

# wind_multi <- st_read("salinasbox/intermediate_data/project_databases/wind_multipoint.gpkg")

## do for polys instead
wind_multi <- st_read("salinasbox/intermediate_data/project_databases/wind_polys.gpkg")
# expand wind project case IDs back out but now multipoint geom is same for all case_IDs associated w project
wind_multi_long <- wind_multi %>%
  separate_longer_delim(cols = project_caseIDs, delim = ", ") %>%
  rename(case_id = project_caseIDs, geometry = geom) %>%
  st_set_geometry("geometry")

solar_polys <- st_read("salinasbox/intermediate_data/project_databases/solar_polys.shp") %>%
  select(case_id, p_name, p_year, geometry) 

st_crs(wind_multi_long) == st_crs(solar_polys)
# true 

#combine wind and solar
wind_solar <- bind_rows(wind_multi_long, solar_polys) %>%
  st_as_sf()

# match to EIS found case IDs
EIS_caseIDs <- read.csv("salinasbox/intermediate_data/project_databases/found_spatial_data.csv") %>%
  separate_longer_delim(cols = Case.ID, delim = ", ") %>%
  filter(!is.na(Case.ID)) %>%
  filter(Case.ID != "")

matched_caseIDs <- left_join(EIS_caseIDs, wind_solar, by = join_by(Case.ID == case_id)) %>%
  select(!Maps.Link) %>%
  st_as_sf()

# create multipolygon for the multiple facilities that might make up one project/doc
eis_locs_caseIDs <- matched_caseIDs %>%
  group_by(EIS.Number) %>%
  summarise(geom_caseID = st_combine(geometry),
            project_caseIDs = paste0(Case.ID, collapse = ", "),
            project_names = paste0(p_name, collapse = ", "),
            project_years = paste0(p_year, collapse = ", "),
            .groups = "drop") %>%
  filter(!st_is_empty(geom_caseID))

st_write(eis_locs_caseIDs,"salinasbox/intermediate_data/project_databases/matched_caseIDs_polys.gpkg", append = F)
