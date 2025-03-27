cleanextractfiles <- list.files("salinasbox/clean_data/minimalist_cleaned_networks", pattern = "cleanedextract", full.names=T)
cleanextracts <- vector(mode = "list", length = length(cleanextractfiles))
cleanextracts <- lapply(cleanextractfiles, 
                     function(i) readRDS(i))
names(cleanextracts) <- substr(list.files("salinasbox/clean_data/minimalist_cleaned_networks", pattern = "cleanedextract", full.names=F),
                            16,23)

library(data.table)
network_graphs <- lapply(cleanextracts, function(i)
  {export_to_network(i, "igraph", keep_isolates = T,
                     collapse_edges = F, self_loops = T)[[1]]})

top_entities <- lapply(network_graphs, function(i) top_features(list(i))$entities)
names(top_entities) <- names(network_graphs)

top_entities <- rbindlist(top_entities, idcol = "EIS.Number")
top_entities$Group.Name <- groupids$Group.Name[match(as.numeric(top_entities$EIS.Number), groupids$EIS.Number)]
#add temporary index to keep only the most common nodes for each eis number
top_entities <- top_entities[, index := seq_len(.N), by = EIS.Number]
#we are keeping only the top 25 here. This can be adjusted as necessary
top_entities <- top_entities[top_entities$index <= 25,]
#remove temp column
top_entities$index <- NULL
colnames(top_entities)[colnames(top_entities)=="avg_fract_of_a_doc"] <- "fraction_of_doc"
write.csv(top_entities, "salinasbox/clean_data/top_entities.csv")