
library(dplyr)
library(httr)
library(purrr)
library(rvest)
library(stringr)
library(sf)

found_locs <- read.csv("salinasbox/intermediate_data/project_databases/found_spatial_data.csv")

# google map links are shortened, need to get full link to get coords from URLs

# helper funcs (thanks to chat gpt) ------------------------------

# safely extract full URLs, return NA on error
safe_get_url <- possibly(function(link) {
  if (!grepl("^https?://", link)) stop("Malformed URL")  # skip malformed URLs
  httr::GET(link, config(followlocation = TRUE))$url
}, otherwise = NA_character_)

# extract coords depending on URL format
extract_coords <- function(original_url, resolved_url = NULL) {
  urls <- c(original_url, resolved_url)
  
  for (url in urls) {
    if (is.na(url)) next
    
    # 1. /search/lat,+lon (allow + or %20 between lat/lon)
    m1 <- regmatches(url, regexec("/search/([-+]?\\d{1,3}\\.\\d+)[+,\\s]+([-+]?\\d{1,3}\\.\\d+)", url))[[1]]
    if (length(m1) == 3) return(c(lat = as.numeric(m1[2]), lon = as.numeric(m1[3])))
    
    # 2. !3dlat!4dlon
    m2 <- regmatches(url, regexec("!3d([-+]?\\d{1,3}\\.\\d+)!4d([-+]?\\d{1,3}\\.\\d+)", url))[[1]]
    if (length(m2) == 3) return(c(lat = as.numeric(m2[2]), lon = as.numeric(m2[3])))
    
    # 3. @lat,lon
    m3 <- regmatches(url, regexec("@([-+]?\\d{1,3}\\.\\d+),([-+]?\\d{1,3}\\.\\d+)", url))[[1]]
    if (length(m3) == 3) return(c(lat = as.numeric(m3[2]), lon = as.numeric(m3[3])))
  }
  
  return(c(lat = NA_real_, lon = NA_real_))
}

# apply to each row
found_locs <- found_locs %>%
  rowwise() %>%
  mutate(
    full_link = if (!is.na(location.link) && location.link != "") {
      safe_get_url(location.link)
    } else {
      NA_character_
    },
    lat = extract_coords(location.link, full_link)["lat"],
    lon = extract_coords(location.link, full_link)["lon"]
  ) %>%
  ungroup()

spatial_locs <- found_locs %>%
  filter(!is.na(lat) & !is.na(lon)) %>%  # remove rows with missing coords
  st_as_sf(coords = c("lon", "lat"), crs = 4326)  # WGS84 (lat/lon)


write.csv(spatial_locs, "salinasbox/intermediate_data/project_databases/google_maps_points.csv")




