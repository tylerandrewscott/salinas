library(igraph)
library(dplyr)
library(stringr)

filtered_networks <- readRDS("salinasbox/clean_data/filtered_networks.RDS")

# add some info about plans to graph as attributes
EIS_info <- read.csv("salinasbox/clean_data/eis_info.csv")
for (i in seq_along(filtered_networks)) {
  name <- names(filtered_networks)[i]
  group <- str_extract(name, "^[^_]+")
  g <- filtered_networks[[i]]
  eis_num <- str_sub(name, -8) # get rid of group prefix so just 8-digit eis number to match on
  # assign as graph attributes
  g <- set_graph_attr(g, "group", group)
  g <- set_graph_attr(g, "eis", eis_num)
  m <- match(eis_num, as.character(EIS_info$EIS)) # get index of matches
  if(!is.na(m)) {
    g <- set_graph_attr(g, "state",        EIS_info$state[m])
    g <- set_graph_attr(g, "lead_agency",  EIS_info$lead_agency[m])
    g <- set_graph_attr(g, "doc_type",     EIS_info$doc_type[m])
    g <- set_graph_attr(g, "year",         EIS_info$year[m])
    g <- set_graph_attr(g, "project_type", EIS_info$project_type[m])
  }
  filtered_networks[[i]] <- g
}

# get graph-level descriptives for each network

network_info <- lapply(seq_along(filtered_networks), function(i) {
  g <- filtered_networks[[i]]
  attributes <- graph_attr(g)
  list(c(attributes,
         n_nodes = vcount(g),
         n_edges = ecount(g),
         density = graph.density(g)
  )
  )
})

network_descriptives <- bind_rows(network_info)

stats_by_proj <- network_descriptives %>%
  group_by(project_type) %>%
  summarise(
    median_nodes = median(n_nodes),
    IQR_nodes = IQR(n_nodes),
    avg_nodes = mean(n_nodes),
    sd_nodes = sd(n_nodes),
    median_edges = median(n_edges),
    IQR_edges = IQR(n_edges),
    avg_edges = mean(n_edges),
    sd_edges = sd(n_edges)
)

stats_overall <- network_descriptives %>%
  summarise(
    median_nodes = median(n_nodes),
    IQR_nodes = IQR(n_nodes),
    avg_nodes = mean(n_nodes),
    sd_nodes = sd(n_nodes),
    median_edges = median(n_edges),
    IQR_edges = IQR(n_edges),
    avg_edges = mean(n_edges),
    sd_edges = sd(n_edges)
  ) %>%
  mutate(project_type = "all")

stats <- bind_rows(stats_by_proj, stats_overall)


hist(network_descriptives$n_edges)
hist(network_descriptives$n_nodes)

ggplot(network_descriptives, aes(x = "", y = n_nodes)) +
  geom_boxplot()+
  coord_flip()

ggplot(network_descriptives, aes(x = "", y = n_edges)) +
  geom_boxplot()+
  coord_flip()

# get avg number of nodes per agency 
agency <- network_descriptives %>%
  group_by(lead_agency, project_type) %>%
  summarise(n_plans = n(),
            avg_nodes = mean(n_nodes),
            sd_nodes = sd(n_nodes),
            avg_edges = mean(n_edges),
            sd_edges = sd(n_edges))
agency_all <- network_descriptives %>%
  group_by(lead_agency) %>%
  summarise(num_plans = n(),
            avg_nodes = mean(n_nodes),
            sd_nodes = sd(n_nodes),
            avg_edges = mean(n_edges),
            sd_edges = sd(n_edges),

ggplot(agency_all, aes(x = lead_agency, y= avg_centr_deg)) +
  geom_col()+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))



# extract giant component of each graph
main_networks <- list()
for (i in seq_along(filtered_networks)) {
  g <- filtered_networks[[i]]
  comp <- components(g) 
  giant_c_index <- which.max(comp$csize)
  giant_c_network <- induced.subgraph(g, which(comp$membership ==giant_c_index))  
  
  main_networks[[names(filtered_networks)[i]]] <- giant_c_network  
}




