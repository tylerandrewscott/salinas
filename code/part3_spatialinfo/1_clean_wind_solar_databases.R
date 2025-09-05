# this script simplified the US wind and solar databases from USGS for Anya to match EIS projects in our sample to by comparing project and eis title names

# consolidate wind turbine database by unique name and year because these will be combined
# manually removed some columns to clean up when first downloading data, in "processing" folder
wind_projs <- read.csv("salinasbox/intermediate_data/project_databases/processing/wind_projects_smaller.csv")
# remove dupes to get single case IDs to make matching easier
wind_projs <- wind_projs[!duplicated(wind_projs[c("p_name", "p_year")]),]
# so now case_id represents one turbine but can match back later to get all turbine geoms
wind_projs <- wind_projs[c("case_id", "t_state", "t_county", "p_name", "p_year")]
# order by state, proj name, etc. to group potentially same or related projects together
wind_projs <- wind_projs[order(wind_projs$t_state, wind_projs$t_county, wind_projs$p_name, wind_projs$p_year),]
write.csv(wind_projs, "salinasbox/intermediate_data/project_databases/USWTDB.csv", row.names = F)

# order solar to group potentially same or related projects together
solar_projs <- read.csv("salinasbox/intermediate_data/project_databases/processing/pv_projects_smaller.csv")
solar_projs <- solar_projs[,-c(6:7)]
solar_projs <- solar_projs[order(solar_projs$p_state, solar_projs$p_county, solar_projs$p_name, solar_projs$p_year),]
write.csv(solar_projs, "salinasbox/intermediate_data/project_databases/USPVDB.csv", row.names = F)

