library(igraph)

filtered_networks <- readRDS("salinasbox/clean_data/filtered_networks.RDS")

# need to associate projects together, use elise's groups csv
groups <- read.csv("salinasbox/clean_data/GroupIDs.csv")

vertex_attr(filtered_networks[[2]])
# why is not resolving "state" and "colorado" for ex a problem? how does this not then like split connections and affect the calculation of network stats?
# remember that GPE is tricky because this could be referenincing Fort Collins as a city or it could be referencing it geographically right?

library(ggraph)

lapply(network_graphs, function(i) table(get.vertex.attribute(i, "AgencyScope")))

ggraph(filtered_networks[[3]], layout = "fr") +
  geom_edge_fan(aes(alpha = weight),
                end_cap = circle(1, "mm"),
                color = "#000000",
                width = 0.3,
                arrow = arrow(angle = 15, length = unit(0.07, "inches"), ends = "last", type = "closed"))+
  geom_node_point(aes(color = entity_type, size = num_appearances),  alpha = 0.6) +
  labs(title = "Example Network Plot") + theme_void()

# figure out why there are still some isolates eg #3 