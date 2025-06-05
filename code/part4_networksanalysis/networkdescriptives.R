library(igraph)
library(dplyr)
library(stringr)
library(statnet)
library(ergm)

filtered_networks <- readRDS("salinasbox/clean_data/filtered_networks.RDS")
# add some info about plans to graph as attributes
EIS_info <- read.csv("salinasbox/intermediate_data/project_databases/EISlist.csv")

for (i in seq_along(filtered_networks)) {
  eis <- names(filtered_networks)[i]
  eis_num <- str_sub(eis, -8) # get rid of group prefix so just 8-digit eis number to match on
  matches <- match(eis_num, EIS_info$EIS) # get index of matches
  if(!is.na(matches)) {
    attr(filtered_networks[[i]], "state") <- EIS_info$state[matches]
    attr(filtered_networks[[i]], "lead_agency") <- EIS_info$lead_agency[matches]
    attr(filtered_networks[[i]], "doc_type") <- EIS_info$doc_type[matches]
    attr(filtered_networks[[i]], "year") <- EIS_info$year[matches]
    attr(filtered_networks[[i]], "project_type") <- EIS_info$project_type[matches]
  }
}

# get graph-level descriptives for each network... what interesting things to pull here?
node_edge_info <- lapply(seq_along(filtered_networks), function(i) {
  network <- filtered_networks[[i]]
  list(
    EIS = str_sub(names(filtered_networks)[i], -8),
    group = attr(filtered_networks[[i]], "group"),
    state = attr(filtered_networks[[i]], "state"),
    doc_type = attr(filtered_networks[[i]], "doc_type"),
    lead_agency = attr(filtered_networks[[i]], "lead_agency"),
    year = attr(filtered_networks[[i]], "year"),
    project_type = attr(filtered_networks[[i]], "project_type"),
    num_nodes = vcount(network),
    num_edges = ecount(network),
    density = graph.density(network),
    max_degree_node = V(network)$name[degree(network)==max(degree(network))],
    max_degree = max(degree(network)),
    centraliz_between = centr_betw(network, directed = F)$centralization,
    # how is this a measure for the entire graph 
    centraliz_deg = centr_degree(network, mode = "total", loops = F)$centralization,
    transitivity = transitivity(network)
  )
})
# as data frame
network_descriptives <- bind_rows(node_edge_info)
network_descriptives$year <- str_sub(network_descriptives$EIS, 1, 4)

network1nodes <- igraph::as_data_frame(filtered_networks[[1]], what = "vertices")
igraph::as_data_frame(filtered_networks[[1]], what = "edges")

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


