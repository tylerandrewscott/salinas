
library(ggraph)

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
  networktype == "raw" ~ "salinasbox/intermediate_data/raw_extracted_networks/",
  networktype == "minimalist" ~ "salinasbox/clean_data/minimalist_cleaned_networks/",
  networktype == "manual" ~ "salinasbox/clean_data/manually_cleaned_networks/",
  T ~ NA
)

myextractfiles <- list.files(filepath, full.names=T)
eis <- substr(myextractfiles, 67, 74)
ca <- c("CA")
western_states <- c("AK", "AZ", "CA", "CO", "HI", "ID",
                    "MT", "NV", "NM", "OR", "UT", "WA", "WY")
mywesternfiles <- myextractfiles[!
  groupids[match(eis, groupids$EIS.Number),]$State %in% western_states]
myextracts <- vector(mode = "list", length = length(mywesternfiles))
myextracts <- lapply(mywesternfiles, 
                     function(i) readRDS(i))

network_graphs <- lapply(myextracts, function(i)
{export_to_network(i, "igraph", keep_isolates = F,
                   collapse_edges = !multiplex, self_loops = T)[[1]]})
ng <- rbindlist(network_graphs)
summary(ng)

lapply(network_graphs, function(i) table(get.vertex.attribute(i, "AgencyScope")))


#state mean degree
stdeg <- unlist(lapply(network_graphs, function(i) {mean(degree(graph = i, 
            v = !is.na(get.vertex.attribute(i, "AgencyScope")) & 
              get.vertex.attribute(i, "AgencyScope") != "federal"))}))

summary(stdeg, na.rm = T)
#federal mean degree
feddeg <- unlist(lapply(network_graphs, function(i) {mean(degree(graph = i, 
            v = !is.na(get.vertex.attribute(i, "AgencyScope")) &
              get.vertex.attribute(i, "AgencyScope") == "federal"))}))
summary(feddeg, na.rm = T)
