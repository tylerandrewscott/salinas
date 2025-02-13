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
