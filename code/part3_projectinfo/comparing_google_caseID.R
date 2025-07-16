## comparing geom for those from case ids and ones anya also found on google maps 
library(sf)
library(dplyr)
caseID_geom <- st_read("salinasbox/intermediate_data/project_databases/matched_caseIDs_polys.gpkg") %>%
  rename(geom_caseID = geom) 
google_geom <- st_read("salinasbox/intermediate_data/project_databases/google_maps_points.gpkg") %>%  select(EIS.Number, geom)

st_crs(caseID_geom) == st_crs(google_geom)
# project to match 
google_geom <- st_transform(google_geom, st_crs(caseID_geom))

google_geom$geom_google <- st_geometry(google_geom)
google_no_geom <- st_set_geometry(google_geom, NULL)
compare_geoms <- left_join(caseID_geom, google_no_geom, by = "EIS.Number") 

#from chatgpt, get distance of google maps point to database provided locations for ones anya did both for just to see how close they are:
compare_geoms <- compare_geoms %>%
  rowwise() %>%
  mutate(
    # Only perform checks when both geometries are present and not empty
    has_both_geoms = !st_is_empty(geom_caseID) & !st_is_empty(geom_google),
    
    is_polygon = if (has_both_geoms) {
      st_geometry_type(geom_caseID) %in% c("POLYGON", "MULTIPOLYGON")
    } else {
      NA
    },
    
    google_within_polygon = if (has_both_geoms & is_polygon == TRUE) {
      st_within(geom_google, geom_caseID, sparse = FALSE)[1, 1]
    } else {
      NA
    },
    
    distance_meters = if (has_both_geoms) {
      as.numeric(st_distance(geom_google, geom_caseID))
    } else {
      NA_real_
    }
  )
# compare_geoms <- compare_geoms %>%
#   select(EIS.Number, EIS.Title, p_name, p_year, geom_caseID, geom_google, google_within_polygon, distance_meters)
# not super close... should we be concerned?

# bring back other info to see if we should use 

# visually compare 

#transform for mapping 
compare_geoms_t <- compare_geoms %>%
  mutate(geom_caseID = st_transform(geom_caseID, crs = 4326),
    geom_google = st_transform(geom_google, crs = 4326))

library(ggplot2)
library(rnaturalearth)
usa <- ne_states(country = "United States of America", returnclass = "sf") %>%
  st_transform(crs = 4326)

ggplot() +
  geom_sf(data = usa, fill = "white", color = "black", size = 0.2) +
  geom_sf(data = compare_geoms_t, aes(geometry = geom_caseID), 
          color = "blue", size = 2) +
  geom_sf(data = compare_geoms_t, aes(geometry = geom_google), 
          color = "red", shape = 1, size = 2) +
  coord_sf(xlim = c(-160, -60), ylim = c(20, 50)) +
  theme_minimal() +
  labs(title = "Project Locations Across the US",
       subtitle = "Blue = Database | Red = Google Maps")

ggplot() +
  geom_sf(data = compare_geoms_t[52,], aes(geometry = geom_caseID), 
          color = "blue", size = 2) +
  geom_sf(data = compare_geoms_t[52,], aes(geometry = geom_google), 
          color = "red", shape = 1, size = 2) +
  theme_minimal() +
  labs(title = "Project Locations Across the US",
       subtitle = "Blue = Database | Red = Google Maps")


library(leaflet)
# and for now bring all geoms for an EIS together (eg when multiple caseIDs were found)
compare_geoms_t <- st_transform(compare_geoms, crs = 4326) %>%
  filter(!st_is_empty(geom_caseID)) %>%
  filter(!st_is_empty(geom_google)) %>%
  select(-p_year)
data_to_add_back <- compare_geoms_t %>%
  st_set_geometry(NULL) %>%
  select(EIS.Number, Document.Type, Project.Type, EIS.Title) %>%
  distinct(EIS.Number, .keep_all = T)
db_locs <- compare_geoms_t %>%
  select(-geom_google) %>%
  group_by(EIS.Number) %>%
  summarise(geom_caseID = st_combine(geom_caseID),
            project_caseIDs = paste0(Case.ID, collapse = ", "),
            project_names = paste0(p_name, collapse = ", "),
            .groups = "drop") 
db_locs <- left_join(db_locs, data_to_add_back, by = "EIS.Number")
gm_locs <- compare_geoms_t %>%
  st_drop_geometry() %>%
  st_set_geometry("geom_google") %>%
  st_transform(crs = 4326) %>%
  distinct(EIS.Number, .keep_all=TRUE)



leaflet() %>%
  addTiles() %>%
  addPolygons(data = db_locs,
              color = "blue", weight = 3, fillOpacity = 0.3,
              label = db_locs$project_names) %>%
  addCircleMarkers(data = gm_locs,
                   color = "red", radius = 6,
                   label = gm_locs$EIS.Title) 


# bring them back together to get new distances
# project so distances are in meters
db_to_compare <- st_transform(db_locs, st_crs(caseID_geom))
gm_to_compare <- st_transform(gm_locs, st_crs(caseID_geom))

gm_to_compare$geom <- st_geometry(gm_to_compare)
gm_comp <- st_set_geometry(gm_to_compare, NULL)
compare_geoms_new <- left_join(db_to_compare, gm_comp, by = "EIS.Number") 


# create multipolygon for the multiple solar facilities that might make up one site
caseID_geoms <- st_read("salinasbox/intermediate_data/project_databases/matched_caseIDs_polys.gpkg") 
EIS_info <- caseID_geoms %>%
  st_set_geometry(NULL) %>%
  select(EIS.Number, Document.Type, Project.Type, EIS.Title) %>%
  distinct(EIS.Number, .keep_all = T)

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
  st_transform(st_crs(caseID_groups))
google_info <- left_join(google_geoms, EIS_info, by = "EIS.Number")
# bring together to get distances

google_geoms$gm_locs <- st_geometry(google_geoms) # add extra column to store when removing geom
google_geoms <- st_set_geometry(google_geoms, NULL)
all_geoms <- full_join(caseID_grouped, google_geoms, by = "EIS.Number") %>%
  rowwise() %>%
  mutate(distance_meters = as.numeric(st_distance(geom_caseID, gm_locs)))
all_geoms_info <- full_join(EIS_info, all_geoms, by = "EIS.Number")

# map for leaflet, transform to WGS84
google_info_t <- st_transform(google_info, 4326)
caseID_info_t <- st_transform(caseID_info, 4326)

leaflet() %>%
  addTiles() %>%
  addPolygons(data = caseID_info_t,
              color = "blue", weight = 3, fillOpacity = 0.3,
              label = caseID_info_t$project_names) %>%
  addCircleMarkers(data = google_info_t,
                   color = "red", radius = 6,
                   label = google_info_t$EIS.Title) 
