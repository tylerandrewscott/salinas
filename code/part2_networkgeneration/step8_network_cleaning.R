#Purpose: The purpose of this script is to take the extracts 
#generated in the previous step and filter out extraneous material
#and then disambiguate the nodes. 

#Setup: This code can be run as is to generate "minimalist" 
#cleaned networks. Optionally, you can
#edit the file "salinasbox/clean_data/manual_disambiguation_key.txt"
#with custom equivalence definitions and then turn manual_disambig to T
#to incorporate these definitions. The file top_entities.csv
#is generated here and may be helpful in deciding what to include
#in the manual_disambiguation_key.

#This requires the textNet package, data.table, and stringr.

manual_disambig = F
library(stringr)
library(textNet)
library(data.table)
myextractfiles <- list.files("salinasbox/intermediate_data/extracted_networks", full.names=T)
myextracts <- vector(mode = "list", length = length(myextractfiles))
myextracts <- lapply(myextractfiles, 
                     function(i) readRDS(i))
names(myextracts) <- substr(list.files("salinasbox/intermediate_data/extracted_networks", full.names=F),
                            9,16)
#this helper function cleans the network. Any filtering steps to 
#filter certain nodes/edges in the network can go here
#if you want to save this intermediate file, save it to a new location and 
#not overwrite the extracted_networks
#this is not the part where we disambiguate nodes; that's later
source("code/part2_networkgeneration/helpers/clean.R")
myextracts <- clean(myextracts)

#the helper code below generates the file called myacronyms,
source("code/part2_networkgeneration/helpers/generateacronyms.R")
#which we now use:

#the helper code below generates the file called top_entities, which we can
#inspect and save as a csv
#this top_entities file can be used to inform manual disambiguation instructions
source("code/part2_networkgeneration/helpers/get_top_nodes.R")
write.csv(top_entities, "salinasbox/clean_data/top_entities.csv")

#the file below is an ID matcher between the Group.Name and the eis numbers
groupids <- read.csv("salinasbox/clean_data/groupIDs.csv")

#to incorporate manual disambiguation instructions,
#update manual_disambiguation_key.csv as desired and then
#turn on the toggle and run

if(manual_disambig = T){
  manual <- read.delim("salinasbox/clean_data/manual_disambiguation_key.txt")
  if(any(str_detect(manual$to, "Example"))){
    stop("The manual disambiguation key needs to be updated with real entity names before generating the disambiguated networks. ")
  }
  
  for(i in seq_along(myextracts)){
    currentgroupname <- groupids$Group.Name[which(groupids$EIS.Number == names(myextracts)[i])]
    #we want to filter for only rows that are relevant for this project group
    current_manuals <- manual[str_squish(manual$Group.Name) == 
                                currentgroupname,]
    #now we combine the acronyms with the manual definitions to make
    #the to and from list that we put into the disambiguator
    if(length(current_manuals$from) > 0){
      from <- append(as.list(myacronyms[[i]]$acronym), as.list(current_manuals$from))
      to <- append(as.list(myacronyms[[i]]$name), stringr::str_split(current_manuals$to, "\\s*,\\s*"))
      
    }else{
      from <- as.list(myacronyms[[i]]$acronym)
      to <- as.list(myacronyms[[i]]$name)
    }
    
    cleaned_extract <- disambiguate(textnet_extract = myextracts[[i]],
                                     from = from,
                                     to = to)
    saveRDS(cleaned_extract, paste0("salinasbox/clean_data/example_only_cleaned_networks/cleanedextract_", names(myextracts)[i], ".RDS"))
  }
}else{
  for(i in seq_along(myextracts)){
    #we just use the acronyms to make the to and from list 
    #that we put into the disambiguator
    from <- as.list(myacronyms[[i]]$acronym)
    to <- as.list(myacronyms[[i]]$name)

    cleaned_extract <- disambiguate(textnet_extract = myextracts[[i]],
                                    from = from,
                                    to = to)
    saveRDS(cleaned_extract, paste0("salinasbox/clean_data/minimalist_cleaned_networks/cleanedextract_", names(myextracts)[i], ".RDS"))
  }
}

#fine print about disambiguate()
#the disambiguate function has several built-in cleaning functions. 
#for instance, it combines nodes that have a preceding "the"
#in the entity name or a trailing "_s" which results from possessives in the original text
#the disambiguate function also consolidates upper and lowercase spellings, and 
#that process is done after the general node matching process, since acronyms and 
#abbreviations can be case-sensitive
