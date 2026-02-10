library(tidycensus)
api_key <- "77b4aae9e134b43d2edeb8aabb1ceb4713fe8a2a"
census_api_key(api_key, install = T)
load_variables(2010)
places <- get_decennial(geography = "place",
                        variables = "P001001",
                        year = 2010) %>%
  separate(NAME, into = c("Place", "State"), sep = ", (?=[^,]+$)") %>% # last comma at end of string
  select(Place, State) %>%
  separate(Place, into = c("Place", "Type"), sep = " (?=\\S+$)") # 
# two were weird, manually fixing since just 2: places[c(1293, 13338),]
places[c(1293, 13338),]
places[1293,]$Place = "Islamorada Village of Islands"
places[1293,]$Type = "village"
places[1293,]$State = "Florida"
places[13338,]$Place = Lynchburg
counties <- get_decennial(geography = "county",
                                    variables = "P001001",
                                    year = 2010)  %>%
  separate(NAME, into = c("County", "State"), sep = ", ") %>%
  select(County, State)

