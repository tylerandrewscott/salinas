
library(sf)
library(dplyr)
library(tidyr)
library(stringr)

# wind projs are points of turbines
uswtdb <- st_read("salinasbox/raw_data/uswindshapefiles/uswtdb_v7_2_20241120.shp")
uswtdb$case_id <- as.character(uswtdb$case_id)
wind_projs <- uswtdb[c("case_id", "t_state", "t_county", "p_name", "p_year", "geometry")]
colnames(wind_projs) <- c("case_id", "state", "county", "p_name", "p_year", "geometry")
wind_projs$type <- "wind"

#solar projs are polys of sites
uspvdb <- st_read("salinasbox/raw_data/ussolarshapefiles/uspvdb_v2_0_20240801.shp")
uspvdb$case_id <- as.character(uspvdb$case_id)
solar_projs <- uspvdb[c("case_id", "p_state", "p_county", "p_name", "p_year", "geometry")]
colnames(solar_projs) <- c("case_id", "state", "county", "p_name", "p_year", "geometry")
solar_projs$type <- "solar"

# solar is projected CRS, wind is not -- so need to project wind to solar 
wind_projs <- st_transform(wind_projs, st_crs(solar_projs))
st_crs(wind_projs) == st_crs(solar_projs) # TRUE

# now get case_ids for other wind turbines in same project as case_id used to match to EIS manually 
# and merge points into multipoint

wind_multipoint <- wind_projs %>%
  group_by(p_name, p_year) %>%
  summarise(
    geometry = st_union(geometry),
    project_caseIDs = paste0(case_id, collapse = ", "), # get groups of case_ids per project
    .groups = "drop") 

#save as geopackage because different geom types and text field limitations
st_write(wind_multipoint, "salinasbox/intermediate_data/project_databases/wind_multipoint.gpkg")

# match to EIS
EIS_caseIDs <- read.csv("salinasbox/intermediate_data/project_databases/found_caseIDs_may22.csv") %>%
  select(c(EIS.Number, EIS.Title, Document.Type, Project.Type, Case.ID))

# split when multiple caseIDs found
EIS_caseIDs_long <- EIS_caseIDs %>%
  separate_longer_delim(cols = Case.ID, delim = ", ")

# expand group back out but now each one has multipoint geom
wind_expanded <- wind_multipoint %>%
  mutate(group_caseID_list = str_split(project_caseIDs, ",\\s*")) %>% # use ",\\s*" instead of ", " in case the spaces between are uneven or if there are no spaces
  unnest(group_caseID_list) %>%
  rename(Case.ID = group_caseID_list)

# so can now match on Case.ID from EIS list but using the single case.id will give multipoint for entire project
wind_matched <- left_join(EIS_caseIDs_long[EIS_caseIDs_long$Project.Type == "Wind",], wind_expanded, by = "Case.ID")

### compare to matching before multipoint
wind_match_point <- left_join(EIS_caseIDs_long[EIS_caseIDs_long$Project.Type == "Wind",], wind_projs, by = join_by("Case.ID" == "case_id")) %>%
  select(EIS.Number, Document.Type, EIS.Title, Case.ID, p_name, Project.Type, geometry)

solar_matched <- left_join(EIS_caseIDs_long[EIS_caseIDs_long$Project.Type == "Solar",], solar_projs, by = join_by("Case.ID" == "case_id")) %>%
  select(EIS.Number, Document.Type, EIS.Title, Case.ID, p_name, Project.Type, geometry)

all_matched <- rbind(solar_matched, wind_match_point)

### NEED TO CHECK THESE, SOME ARE NOT OBVIOUS MATCHES






## replace this with read all .shp in folder
crithab_line <- st_read("salinasbox/raw_data/crithab_all_layers/CRITHAB_LINE.shp")
crithab_poly <- st_read("salinasbox/raw_data/crithab_all_layers/crithab_poly.shp")
tribal_lands <- st_read("salinasbox/raw_data/tl_2022_us_aiannh/tl_2022_us_aiannh.shp")

gis_list <- list(crithab_line, crithab_poly, tribal_lands)

## workflow will be to project all files to match solar_projs equal area projection
gis_list_transformed <- lapply(gis_list, function(x) {
  if (st_crs(x) != st_crs(solar_projs)) {
    st_transform(x, st_crs(solar_projs)) 
  } else {
      x
    }
  })



# what the polygons look like 
plot(st_geometry(ex2[ex2$p_name == "25 Mile Creek",], max.plot = 1))
plot(st_geometry(ex[ex$p_name == "25 Mile Creek",]), col = 'black', add = TRUE)

# what a linestrings look like 
plot(st_geometry(ex2[ex2$p_name == "6th Space Warning Squadron",], max.plot = 1))
plot(st_geometry(ex[ex$p_name == "6th Space Warning Squadron",]), col = 'black', add = T)


