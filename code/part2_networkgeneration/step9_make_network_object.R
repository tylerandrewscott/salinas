#Purpose: to export extracts to network objects for
#visualization or TBD network analysis

source("code/config.R")
library(ggraph)
library(textNet)
library(stringr)


#Setup:
#choose type of networks to use: raw, minimalist, or manual
#(see previous step for explanation)
networktype = "minimalist"
#decide whether you want a multiplex graph or a weighted graph
#a bunch of network statistics can't be calculated with a 
#multiplex graph, so I recommend weighted if you're going to 
#use network statistics. But the edge attributes are lost
#in a weighted network, so if you want those, use multiplex
#if you want to make visual plots of the networks, use the weighted, since 
#multiplex looks too messy
multiplex = F

filepath <- dplyr::case_when(
  networktype == "raw" ~ paste0("salinasbox/intermediate_data/raw_extracted_networks", app_suffix, "/"),
  networktype == "minimalist" ~ paste0("salinasbox/clean_data/minimalist_cleaned_networks", app_suffix, "/"),
  networktype == "manual" ~ paste0("salinasbox/clean_data/manually_cleaned_networks", app_suffix, "/"),
  T ~ NA
)

myextractfiles <- list.files(filepath, full.names=T,pattern = 'V2')
myextracts <- vector(mode = "list", length = length(myextractfiles))
myextracts <- lapply(myextractfiles, 
                     function(i) readRDS(i))

network_graphs <- lapply(myextracts, function(i)
{export_to_network(i, "igraph", keep_isolates = F,
                   collapse_edges = !multiplex, self_loops = T)[[1]]})

# match EIS numbers to network graphs
extracts_names <- paste0("EIS_", (str_extract(basename(myextractfiles),'^[0-9]{8}')))
names(network_graphs) <- extracts_names
saveRDS(network_graphs, paste0("salinasbox/intermediate_data/network_graphs_all_entities_V2", app_suffix, ".RDS"))

#here's the plot of the first EIS as an example
#on a weighted network without isolates
ggraph(network_graphs[[1]], layout = "fr") +
  geom_edge_fan(aes(alpha = weight),
                end_cap = circle(1, "mm"),
                color = "#000000",
                width = 0.3,
                arrow = arrow(angle = 15, length = unit(0.07, "inches"), ends = "last", type = "closed"))+
  geom_node_point(aes(color = entity_type, size = num_appearances),  alpha = 0.6) +
  labs(title = "Example Network Plot") + theme_void()
