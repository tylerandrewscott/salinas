library(rvest)
library(dplyr)

### this is for state agencies in the US wikipedia page

# first need to get links to each of the state pages on main wikipedia page and pull state names
# then go into each link and get the names of each page listed (for state agencies of each state)

library(rvest)
library(dplyr)

# Function to scrape agency names from a state's category page
get_state_agencies <- function(url, state_name) {
  Sys.sleep(1)  # Be polite to Wikipedia servers
  
  tryCatch({
    page <- read_html(url)
    
    # Get agency names from the category page (skip subcategories)
    agencies <- page %>%
      html_nodes("#mw-pages .mw-category-group li a") %>%
      html_text()
    
    # Return data frame
    data.frame(
      state = state_name,
      agency = agencies,
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    message(paste("Error scraping", state_name, ":", e$message))
    return(data.frame(state = state_name, agency = NA, stringsAsFactors = FALSE))
  })
}

# Get the main category page
main_url <- "https://en.wikipedia.org/wiki/Category:State_agencies_of_the_United_States_by_state"
main_page <- read_html(main_url)

# Extract subcategory links (these are the state pages)
subcategory_links <- main_page %>%
  html_nodes("#mw-subcategories .mw-category-group li a") %>%
  html_attr("href") %>%
  paste0("https://en.wikipedia.org", .)

# Extract state names from the subcategory text
state_names <- main_page %>%
  html_nodes("#mw-subcategories .mw-category-group li a") %>%
  html_text() %>%
  gsub("State agencies of ", "", .) 
  
# Create a data frame of states and their URLs
state_info <- data.frame(
  state = state_names,
  url = subcategory_links,
  stringsAsFactors = FALSE
)
# remove empties
state_info <- state_info %>%
  filter(state != "")

# Initialize empty list to store results
all_agencies_list <- list()

# Loop through each state and scrape agencies
for(i in 1:nrow(state_info)) {
  message(paste("Scraping", state_info$state[i], "..."))
  all_agencies_list[[i]] <- get_state_agencies(state_info$url[i], state_info$state[i])
}

# Combine all results into one data frame
all_agencies <- bind_rows(all_agencies_list)

# View results
head(all_agencies, 20)

# Summary by state
all_agencies %>%
  filter(!is.na(agency)) %>%
  count(state) %>%
  arrange(desc(n))

# Save to CSV if desired
write.csv(all_agencies, "state_agencies.csv", row.names = FALSE)


### enviro orgs 
### had some weird structuring so got all content
url <- "https://en.wikipedia.org/wiki/List_of_environmental_and_conservation_organizations_in_the_United_States"
page <- read_html(url)

# Get all list items from the main content
# This should get both state-specific and nationwide sections
all_orgs <- page %>%
  html_nodes(".mw-parser-output ul li") %>%
  html_text() %>%
  trimws()

# Create data frame
env_orgs <- data.frame(
  organization = all_orgs,
  stringsAsFactors = FALSE
)

# remove bottom of page link stuff
env_orgs[1:221,]

# Save
write.csv(env_orgs, "environmental_orgs.csv", row.names = FALSE)


### electric companies by states

url <- "https://en.wikipedia.org/wiki/List_of_United_States_electric_companies"
page <- read_html(url)

# Get all list items from the main content
companies <- page %>%
  html_nodes(".mw-parser-output ul li") %>%
  html_text() %>%
  trimws()

# Create data frame
electric_companies <- data.frame(
  state = "",
  electric_company = companies,
  stringsAsFactors = FALSE
)
# manually add state based on wikipedia page after saving as csv

write.csv(electric_companies, "salinasbox/intermediate_data/dictionaries/electric_companies.csv", row.names = FALSE)
