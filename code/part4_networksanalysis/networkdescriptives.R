library(igraph)
library(dplyr)
library(stringr)

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
    # max_degree_node = V(network)$name[degree(network)==max(degree(network))],
    # max_degree = max(degree(network)),
    centraliz_between = centr_betw(network, directed = F)$centralization,
    # how is this a measure for the entire graph 
    centraliz_deg = centr_degree(network, mode = "total", loops = F)$centralization,
    transitivity = transitivity(network)
  )
})
# as data frame
network_descriptives <- bind_rows(node_edge_info)


## let's check out distributions of these measures across our dataset
hist(network_descriptives$centraliz_deg)

# get avg number of nodes per agency 
agency <- network_descriptives %>%
  group_by(lead_agency, project_type) %>%
  summarise(num_plans = n(),
            avg_nodes = mean(num_nodes),
            sd_nodes = sd(num_nodes),
            avg_edges = mean(num_edges),
            sd_edges = sd(num_edges))
agency_all <- network_descriptives %>%
  group_by(lead_agency) %>%
  summarise(num_plans = n(),
            avg_nodes = mean(num_nodes),
            sd_nodes = sd(num_nodes),
            avg_edges = mean(num_edges),
            sd_edges = sd(num_edges),
            avg_centr_deg = mean(centraliz_deg))
            
ggplot(agency_all, aes(x = lead_agency, y= avg_centr_deg)) +
  geom_col()+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


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


