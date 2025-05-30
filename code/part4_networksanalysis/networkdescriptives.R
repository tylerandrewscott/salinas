library(igraph)
library(dplyr)

filtered_networks <- readRDS("salinasbox/clean_data/filtered_networks.RDS")

# add some info about plans to graph as attributes
library(stringr)
plan_deets <- readRDS("salinasbox/solarwind_project_details.RDS")
for (i in seq_along(filtered_networks)) {
  eis <- names(filtered_networks)[i]
  eis_num <- str_sub(eis, -8) # get rid of "EIS_" so just number to match on
  matches <- match(eis_num, plan_deets$EIS.Number) # get index of matches
  if(!is.na(matches)) {
    attr(filtered_networks[[i]], "state") <- plan_deets$State[matches]
    attr(filtered_networks[[i]], "lead_agency") <- plan_deets$Agency[matches]
    attr(filtered_networks[[i]], "doc_type") <- plan_deets$Document[matches]
  }
}

library(statnet)
library(ergm)

# get graph-level descriptives for each network... what interesting things to pull here?
node_edge_info <- lapply(seq_along(filtered_networks), function(i) {
  network <- filtered_networks[[i]]
  list(
    EIS = str_sub(names(filtered_networks)[i], -8),
    group = attr(filtered_networks[[i]], "group"),
    state = attr(filtered_networks[[i]], "state"),
    doc_type = attr(filtered_networks[[i]], "doc_type"),
    lead_agency = attr(filtered_networks[[i]], "lead_agency"),
    num_nodes = vcount(network),
    num_edges = ecount(network),
    density = graph.density(network),
    max_degree_node = V(network)$name[degree(network)==max(degree(network))],
    centralization_deg = centr_degree(network, mode = "total", loops = F)$centralization,
    transitivity = transitivity(network)
  )
})
# as data frame
network_descriptives <- bind_rows(node_edge_info)


network1nodes <- igraph::as_data_frame(filtered_networks[[1]], what = "vertices")

vertex_attr(filtered_networks[[1]])
# why is not resolving "state" and "colorado" for ex a problem? how does this not then like split connections and affect the calculation of network stats?
# --> answer is "have to accept some level of tolerable noise"
# remember that GPE is tricky because this could be referenincing Fort Collins as a city or it could be referencing it geographically right?



library(ggraph)

# lapply(network_graphs, function(i) table(get.vertex.attribute(i, "AgencyScope")))

## aiya 1
ggraph(filtered_networks[[1]], layout = "fr") +
  geom_edge_fan(aes(alpha = weight),
                end_cap = circle(1, "mm"),
                color = "#000000",
                width = 0.3,
                arrow = arrow(angle = 15, length = unit(0.07, "inches"), ends = "last", type = "closed"))+
  geom_node_point(aes(color = entity_type, size = num_appearances),  alpha = 0.6) +
  labs(title = paste0(names(filtered_networks[1]))) + theme_void()

ggraph(filtered_networks[[2]], layout = "fr") +
  geom_edge_fan(aes(alpha = weight),
                end_cap = circle(1, "mm"),
                color = "#000000",
                width = 0.3,
                arrow = arrow(angle = 15, length = unit(0.07, "inches"), ends = "last", type = "closed"))+
  geom_node_point(aes(color = entity_type, size = num_appearances),  alpha = 0.6) +
  labs(title = paste0(names(filtered_networks[2]))) + theme_void()


