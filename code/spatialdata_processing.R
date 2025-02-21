# seeing what data looks like
library(sf)
wind_projs <- st_read("salinasbox/raw_data/uswindshapefiles/uswtdb_v7_2_20241120.shp")
ex <- wind_projs[wind_projs$p_name == "Skookumchuck",]
# library(dplyr)
# ex <- ex %>%
#   select(case_id, t_state, t_county, t_fips, p_name, p_year)
# geom is points of turbine location 
plot(ex, max.plot = 1)

# for solar geom is polys of sites
solar_projs <- st_read("salinasbox/raw_data/ussolarshapefiles/uspvdb_v2_0_20240801.shp")
plot(solar_projs[4,], max.plot = 1)

## replace this with read in all .shp in folder
crithab_line <- st_read("salinasbox/raw_data/crithab_all_layers/CRITHAB_LINE.shp")
crithab_poly <- st_read("salinasbox/raw_data/crithab_all_layers/crithab_poly.shp")
tribal_lands <- st_read("salinasbox/raw_data/tl_2022_us_aiannh/tl_2022_us_aiannh.shp")

gis_list <- list(crithab_line, crithab_poly, tribal_lands)

## workflow will be to project all files to match solar_projs equal area projection (including wind turbine locations)
gis_list_transformed <- lapply(gis_list, function(x) {
  if (st_crs(x) != st_crs(solar_proj)) {
    st_transform(x, st_crs(solar_projs)) 
  } else {
      x
    }
  })

# ex <- st_transform(ex, st_crs(solar_projs))
# ex2 <- st_transform(ex2, st_crs(solar_projs))

library(dplyr)
#turn wind turbine points into polygons
ex <- wind_projs[1:80,]
ex2 <- ex %>%
  group_by(p_name, p_year) %>% # get turbines from same year at same project
  summarise(geometry = st_union(geometry)) %>% # merge into multipoint 
  mutate(geometry = st_convex_hull(geometry)) %>%  
  rowwise() %>% # add buffers to points and lines that result if didn't make polygon
  mutate(geometry = if (st_geometry_type(geometry) != "POLYGON") {
    st_buffer(geometry, dist = 1)
  } else {
    geometry
  }) %>%
  ungroup()

# what the polygons look like 
plot(st_geometry(ex2[ex2$p_name == "25 Mile Creek",], max.plot = 1))
plot(st_geometry(ex[ex$p_name == "25 Mile Creek",]), col = 'black', add = TRUE)

# what a linestrings look like 
plot(st_geometry(ex2[ex2$p_name == "6th Space Warning Squadron",], max.plot = 1))
plot(st_geometry(ex[ex$p_name == "6th Space Warning Squadron",]), col = 'black', add = T)





if (n)
  
  
#   ))
#   if (st_geometry_type(ex2[i,]) != "POLYGON") 
#     mutate(geometry = st_buffer(ex2[i,], dist = 1))
#   else mutate(geometry = geometry)
# }
# 
# if (st_geometry_type())
#   case_when(st_geometry_type(geometry) != "POLYGON" ~ mutate(geometry = st_buffer(geometry, dist = 10), geometry = geometry))







