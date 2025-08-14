library(igraph)
library(dplyr)
networks <- readRDS("salinasbox/clean_data/filtered_networks.RDS")

dir.create("salinasbox/intermediate_data/node_cleaning", showWarnings = F, recursive = T)

top_nodes_all_networks <- list()
for (i in seq_along(networks)) {
  g <- networks[[i]] 
  network_name <- names(networks)[[i]]
  deg <- degree(networks[[i]], mode = "all")
  # btw <- betweenness(g, directed = is.directed(g))
  # eig <- eigen_centrality(g)$vector
node_names <- V(g)$name

# store as df per network
nodes <- data.frame(
  network = network_name,
  node    = node_names,
  degree  = deg,
  row.names = NULL) 

# get top 30 
top_nodes <- nodes %>%
  arrange(desc(degree)) %>%
  slice_head(n = 30)

top_nodes_all_networks[[i]] <- top_nodes
}

# save as csv 
top_nodes_df <- bind_rows(top_nodes_all_networks)
write.csv(top_nodes_df, "salinasbox/intermediate_data/node_cleaning/top_nodes_deg.csv", row.names = FALSE)