## comparing geom for those from case ids and ones anya also found on google maps 
libary(sf)
caseID_geom <- st_read("salinasbox/intermediate_data/project_databases/matched_caseIDs.gpkg") %>%
  select(EIS.Number, geom) %>%
  filter(!st_is_empty(geom))
google_geom <- st_read("salinasbox/intermediate_data/project_databases/google_maps_points.gpkg") %>%
  select(EIS.Number, geom) 

st_crs(caseID_geom) == st_crs(google_geom)
google_geom <- st_transform(google_geom, st_crs(caseID_geom))


dupe_locs_EIS <- intersect(caseID_geom$EIS.Number, google_geom$EIS.Number)
