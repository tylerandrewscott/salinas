source("code/config.R")
library(igraph)
library(stringr)

network_graphs <- readRDS(paste0("salinasbox/intermediate_data/network_graphs_all_entities_V2", app_suffix, ".RDS"))
# want to filter for certain entity types, remove isolates, and clean up some nodes
filtered_networks <- lapply(network_graphs, function(network) {
  # only keep entity types we want
  keep_entities <- c("PERSON", "ORG", "GPE", "PARTIES", "CUSTOM", "DICT", "PATTERN")
  filtered <- induced_subgraph(network, V(network)[vertex_attr(network,"entity_type") %in% keep_entities])
  # remove isolates
  isolates <- which(igraph::degree(filtered) == 0)
  no_isolates <- igraph::delete_vertices(filtered, isolates)
  # clean nodes up
  keep_abbvs <- tolower(c(state.abb, "US", "DC"))
  drop_weird <- c("ghg", "llc", "limited_liability_corporation", "dba")
  # remove weird common nodes and those with 2 or fewer chars that are not state or us abbreviations
  clean_nodes <- induced_subgraph(no_isolates, (V(no_isolates)[!(name %in% drop_weird) & (name %in% keep_abbvs | nchar(name) > 2)]))
  return(clean_nodes)
})

# associate networks with group ID to link related projects
groups <- read.csv("salinasbox/clean_data/GroupIDs.csv")
for (i in seq_along(filtered_networks)) {
  eis <- names(filtered_networks)[i]
  eis_num <- sub("EIS_", "", eis) # get rid of "EIS_" so just number to match on
  matched_group <- groups$Group.Name[eis_num == groups$ceqNumber]
  filtered_networks[[i]]$group <- ifelse(length(matched_group) != 0, matched_group, NA)
}


# manually remove networks for docs we removed after fixing preprocessing code (step3) to get final sample
network_nums <- stringr::str_extract(names(filtered_networks), "\\d{8}$")
eis_info <- read.csv("salinasbox/clean_data/eis_info_V2.csv")
final_nums <- as.character(eis_info$ceqNumber)
filtered_networks <- filtered_networks[network_nums %in% final_nums]

saveRDS(filtered_networks, paste0("salinasbox/clean_data/filtered_networks", app_suffix, ".RDS"))

# 
# ## old network graph ex
# ggraph(network_graphs[[1]], layout = "fr") +
#   geom_edge_fan(aes(alpha = weight),
#                 end_cap = circle(1, "mm"),
#                 color = "#000000",
#                 width = 0.3,
#                 arrow = arrow(angle = 15, length = unit(0.07, "inches"), ends = "last", type = "closed"))+
#   geom_node_point(aes(color = entity_type, size = num_appearances),  alpha = 0.6) +
#   labs(title = "Example Network Plot") + theme_void()
# 
# ## filtered network graph example
# ggraph(filtered_networks[[1]], layout = "fr") +
#   geom_edge_fan(aes(alpha = weight),
#                 end_cap = circle(1, "mm"),
#                 color = "#000000",
#                 width = 0.3,
#                 arrow = arrow(angle = 15, length = unit(0.07, "inches"), ends = "last", type = "closed"))+
#   geom_node_point(aes(color = entity_type, size = num_appearances),  alpha = 0.6) +
#   labs(title = "Example Network Plot") + theme_void()

