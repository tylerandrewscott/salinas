## comparing geom for those from case ids and ones anya also found on google maps (by mistake, but provided a useful way to check if our estimations were reasonable. i'd say they are fine)

library(sf)
library(dplyr)
library(leaflet)
library(htmlwidgets)
library(leaflet.extras)

caseID_geoms <- st_read("salinasbox/intermediate_data/project_databases/matched_caseIDs_polys.gpkg") 
EIS_info <- caseID_geoms %>%
  st_set_geometry(NULL) %>%
  select(EIS.Number, Document.Type, Project.Type, EIS.Title) %>%
  distinct(EIS.Number, .keep_all = T)

# create multipolygon for the multiple solar facilities that might make up one site
caseID_grouped <- caseID_geoms %>%
  group_by(EIS.Number) %>%
  summarise(geom_caseID = st_combine(geom),
            project_caseIDs = paste0(Case.ID, collapse = ", "),
            project_names = paste0(p_name, collapse = ", "),
            project_years = paste0(p_year, collapse = ", "),
            .groups = "drop") %>%
  filter(!st_is_empty(geom_caseID))
caseID_info<- left_join(caseID_grouped, EIS_info, by = "EIS.Number")

google_geoms <- st_read("salinasbox/intermediate_data/project_databases/google_maps_points.gpkg") %>% 
  select(EIS.Number, geom) %>%
  distinct(EIS.Number, .keep_all = T) %>%
  st_transform(st_crs(caseID_grouped)) # because will need meters for distances
google_info <- left_join(google_geoms, EIS_info, by = "EIS.Number")

# now bring together to get distances
google_geoms$gm_locs <- st_geometry(google_geoms) # add extra column to store when removing geom
google_geoms <- st_set_geometry(google_geoms, NULL)
geom_distances <- full_join(caseID_grouped, google_geoms, by = "EIS.Number") %>%
  rowwise() %>%
  mutate(distance_meters = as.numeric(st_distance(geom_caseID, gm_locs)))
geom_distances <- full_join(EIS_info, geom_distances, by = "EIS.Number") %>%
  select(EIS.Number, Document.Type, Project.Type, EIS.Title, project_names, project_years, project_caseIDs, geom_caseID, gm_locs, distance_meters)

# check where google maps points versus caseID polys are
# map for leaflet, transform to WGS84
google_info_t <- st_transform(google_info, 4326)
caseID_info_t <- st_transform(caseID_info, 4326)

map <- leaflet() %>%
  addTiles() %>%
  addPolygons(data = caseID_info_t,
              color = "blue", weight = 3, fillOpacity = 0.3,
              label = caseID_info_t$project_names,
              group = "caseIDs") %>%
  addCircleMarkers(data = google_info_t,
                   color = "red", radius = 6,
                   label = google_info_t$EIS.Title,
                   group = "maps_locs") %>%
  addSearchFeatures(targetGroups = "caseIDs", 
                    options = searchFeaturesOptions(
                      propertyName = "project_names",
                      zoom = 10,                   
                      openPopup = TRUE, 
                      firstTipSubmit = TRUE,
                      autoCollapse = TRUE,
                      hideMarkerOnCollapse = TRUE))
## figure out search bar 
map

saveWidget(map, "salinasbox/intermediate_data/project_databases/map_locs2.html", selfcontained = TRUE)

only_caseIDs <- geom_distances %>%
  filter(!st_is_empty(geom_caseID)) 
length(unique(only_caseIDs$geom_caseID))
only_googs <- geom_distances %>%
  filter(st_is_empty(geom_caseID)) %>%
  filter(!st_is_empty(gm_locs))
length(unique(only_googs$gm_locs))
no_locs <- geom_distances %>%
  filter(st_is_empty(geom_caseID)) %>%
  filter(st_is_empty(gm_locs))

geom_distances <- geom_distances %>%
  arrange(EIS.Title) %>%
  relocate(gm_locs, .after = EIS.Title) %>%
  relocate(geom_caseID, .after = gm_locs) 
