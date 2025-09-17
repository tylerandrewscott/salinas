library(igraph)
library(stringr)

network_graphs <- readRDS("salinasbox/intermediate_data/network_graphs_all_entities.RDS")
# want to filter for certain entity types, remove isolates, and clean up some nodes
filtered_networks <- lapply(network_graphs, function(network) {
  # only keep entity types we want
  keep_entities <- c("PERSON", "ORG", "GPE", "PARTIES")
  filtered <- induced_subgraph(network, V(network)[vertex_attr(network,"entity_type") %in% keep_entities])
  # remove isolates
  isolates <- which(igraph::degree(filtered) == 0)
  no_isolates <- igraph::delete.vertices(filtered, isolates)
  # clean nodes up
  keep_abbvs <- tolower(c(state.abb, "US", "DC"))
  drop_weird <- c("ghg", "llc", "limited_liability_corporation", "dba")
  # remove weird common nodes and those with 2 or fewer chars that are not state or us abbreviations
  clean_nodes <- induced_subgraph(no_isolates, (V(no_isolates)[!(name %in% drop_weird) & (name %in% keep_abbvs | nchar(name) > 2)]))
  return(clean_nodes)
})

# associate networks with group ID to link related projects and add to network object name
groups <- read.csv("salinasbox/clean_data/GroupIDs.csv")
new_names <- names(filtered_networks) # initialize vector to replace with new names
for (i in seq_along(filtered_networks)) {
  eis <- names(filtered_networks)[i]
  eis_num <- sub("EIS_", "", eis) # get rid of "EIS_" so just number to match on
  matches <- match(eis_num, groups$EIS.Number) # get index of matches
  if(!is.na(matches)) {
    attr(filtered_networks[[i]], "group") <- groups$Group.Name[matches] # make attribute for group name
  }
  if (!is.na(attr(filtered_networks[[i]], "group")) && !is.null(attr(filtered_networks[[i]], "group"))) {
    new_names[i] <- paste0(attr(filtered_networks[[i]], "group"), "_", eis_num) # make vector of new names with _group added
  } 
}
# assign new names
names(filtered_networks) <- new_names
filtered_networks <- filtered_networks[order(names(filtered_networks))]

# manually remove networks for docs we removed after fixing preprocessing code (step3) to get final sample
network_nums <- stringr::str_extract(names(filtered_networks), "\\d{8}$")
eis_info <- read.csv("salinasbox/clean_data/eis_info.csv")
final_nums <- as.character(eis_info$EIS.Number)
filtered_networks <- filtered_networks[network_nums %in% final_nums]

saveRDS(filtered_networks, "salinasbox/clean_data/filtered_networks.RDS")


## old network graph ex
ggraph(network_graphs[[1]], layout = "fr") +
  geom_edge_fan(aes(alpha = weight),
                end_cap = circle(1, "mm"),
                color = "#000000",
                width = 0.3,
                arrow = arrow(angle = 15, length = unit(0.07, "inches"), ends = "last", type = "closed"))+
  geom_node_point(aes(color = entity_type, size = num_appearances),  alpha = 0.6) +
  labs(title = "Example Network Plot") + theme_void()

## filtered network graph example
ggraph(filtered_networks[[1]], layout = "fr") +
  geom_edge_fan(aes(alpha = weight),
                end_cap = circle(1, "mm"),
                color = "#000000",
                width = 0.3,
                arrow = arrow(angle = 15, length = unit(0.07, "inches"), ends = "last", type = "closed"))+
  geom_node_point(aes(color = entity_type, size = num_appearances),  alpha = 0.6) +
  labs(title = "Example Network Plot") + theme_void()

