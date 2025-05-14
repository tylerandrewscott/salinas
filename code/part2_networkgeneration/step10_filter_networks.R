library(igraph)

network_graphs <- readRDS("salinasbox/intermediate_data/network_graphs_all_entities.RDS")
# want to filter for certain entity types
networks_filtered <- lapply(network_graphs, function(network) {
  # only keep entity types we want
  filtered <- subgraph(network, V(network)[vertex_attr(network,"entity_type") %in% c("PERSON", "NORP", "ORG", "GPE", "PARTIES")])
  # remove isolates
  isolates <- which(igraph::degree(filtered) == 0)
  filtered_no_iso <- igraph::delete.vertices(filtered, isolates)
  
  return(filtered_no_iso)
})


ggraph(network_graphs[[1]], layout = "fr") +
  geom_edge_fan(aes(alpha = weight),
                end_cap = circle(1, "mm"),
                color = "#000000",
                width = 0.3,
                arrow = arrow(angle = 15, length = unit(0.07, "inches"), ends = "last", type = "closed"))+
  geom_node_point(aes(color = entity_type, size = num_appearances),  alpha = 0.6) +
  labs(title = "Example Network Plot") + theme_void()

ggraph(networks_filtered[[5]], layout = "fr") +
  geom_edge_fan(aes(alpha = weight),
                end_cap = circle(1, "mm"),
                color = "#000000",
                width = 0.3,
                arrow = arrow(angle = 15, length = unit(0.07, "inches"), ends = "last", type = "closed"))+
  geom_node_point(aes(color = entity_type, size = num_appearances),  alpha = 0.6) +
  labs(title = "Example Network Plot") + theme_void()

graph_before_filtering
graph_after_filtering


E(networks_filtered[[5]])
