#Purpose: The purpose of this script is to take the extracts 
#generated in the previous step and filter out extraneous material
#and then disambiguate the nodes.

#Setup: This code was run as is to generate "minimalist" 
#cleaned networks. Optionally, you can
#edit the file "salinasbox/clean_data/manual_disambiguation_key.txt"
#with custom equivalence definitions and then turn manual_disambig to T
#to incorporate these definitions. The file top_entities.csv
#is generated here and may be helpful in deciding what to include
#in the manual_disambiguation_key. 
#If going this route, after editing the manual_disambiguation_key, change the save filepath 
#from example_only_cleaned_networks to manually_cleaned_networks

#This requires the textNet package, data.table, and stringr.

#Note: when disambiguating nodes, it's important to 
#always use textNet::disambiguate, like this script does,
#rather than designing something ad-hoc separately
#because textNet::disambiguate updates both the nodelist and 
#edgelist and has various quality control measures.

manual_disambig = F
library(stringr)
library(textNet)
library(data.table)
myextractfiles <- list.files("salinasbox/intermediate_data/raw_extracted_networks", full.names=T)
myextracts <- vector(mode = "list", length = length(myextractfiles))
myextracts <- lapply(myextractfiles, 
                     function(i) readRDS(i))
names(myextracts) <- substr(list.files("salinasbox/intermediate_data/raw_extracted_networks", full.names=F),
                            9,16)
#this helper function cleans the network. Any filtering steps to 
#filter certain nodes/edges in the network can go here
#if you want to save this intermediate file, save it to a new location and 
#not overwrite the raw_extracted_networks
#this is not the part where we disambiguate nodes; that's later
source("code/part2_networkgeneration/helpers/clean.R")
myextracts <- clean(myextracts)

#the file below is an ID matcher between the Group.Name and the eis numbers
groupids <- read.csv("salinasbox/clean_data/groupIDs.csv")

#the helper code below generates the file called top_entities, which we can
#inspect and save as a csv
#this top_entities file can be used to inform manual disambiguation instructions
source("code/part2_networkgeneration/helpers/get_top_nodes.R")
write.csv(top_entities, "salinasbox/clean_data/top_entities.csv")

#the helper code below generates the file called myacronyms,
source("code/part2_networkgeneration/helpers/generateacronyms.R")
myacronyms <- readRDS("salinasbox/intermediate_data/project_specific_acronyms.RDS")

#this file generates RDS files that contain the agency dictionary we will use
#to 1) further disambiguate nodes and 2) tag them with their AgencyScope
source("code/part2_networkgeneration/helpers/generate_agency_dictionaries.R")
for_disambig <- readRDS("salinasbox/intermediate_data/agencylist_for_disambiguation.RDS")
for_entity_dictionary <- readRDS("salinasbox/intermediate_data/agencylist_for_entitydictionary.RDS")

#now we add the agency list to the myacronyms that are specific to the plan
#we will prefer using the plan-specific acronym and will add the 
#agency list abbreviations if they are either federal or 
#in the project's state and don't 
#conflict with the plan-specific acronyms
#we also make a custom version of for_entity_dictionary subset by state
#called entitydict
entitydict <- vector(mode = "list", length = length(myacronyms))

#now we combine the myacronyms (which are project-specific)
#with the list of known federal and state agencies
for(i in 1:length(myacronyms)){
  myacronyms[[i]]$State <- NA
  myacronyms[[i]] <- rename(myacronyms[[i]], all_of(c(
    from = "acronym",
    to = "name"
  )))
  myacronyms[[i]] <- data.table::rbindlist(list(myacronyms[[i]], for_disambig),
                                           use.names = T)
  stateabbr <- groupids$State[groupids$EIS.Number == names(myacronyms)[i]]
  statename <- state.name[state.abb == stateabbr]
  #filter for only local state, federal, and plan-specific acronyms
  #we aren't including out-of-state here in myacronyms because the point of disambiguating is 
  #mostly to change from informal to formal name, but for out-of-state agencies,
  #we should require them to say the formal name including the state name, since
  #many states have identically named departments. We handle that with the entitydict later
  myacronyms[[i]] <- myacronyms[[i]][is.na(myacronyms[[i]]$State) | myacronyms[[i]]$State %in% 
                                       c(statename, "federal"),]
  #for entitydict,  we do an ordered rbind so that out-of-state agencies
  #are captured but not preferenced if there is a duplicate.
  #We reorder for_entity_dictionary so that federal agencies are at the top
  #and then the state where the project is located, 
  #then out-of-state agencies only if the state name is explicitly mentioned 
  #(because many states have identically named orgs).
  #This ordering influences the duplication removal preference
  #the if statement treats the "Multi" states differently to avoid an error due to lacking statename
  if(length(statename)>0){
    entitydict[[i]] <- rbind(for_entity_dictionary[for_entity_dictionary$State == "federal",],
                             for_entity_dictionary[for_entity_dictionary$State == statename,],
                             for_entity_dictionary[!for_entity_dictionary$State %in% c(statename, "federal") &
                                                     for_entity_dictionary$Type == "NameWithState",])
    
  }else{
    entitydict[[i]] <- rbind(for_entity_dictionary[for_entity_dictionary$State == "federal",],
                             for_entity_dictionary[for_entity_dictionary$State != "federal" &
                                                     for_entity_dictionary$Type == "NameWithState",])
  }
  
  #remove duplicates, preferencing the top of the dataframe, which is the
  #plan-specific acronyms
  myacronyms[[i]] <- myacronyms[[i]][!duplicated(myacronyms[[i]]$from),]
  entitydict[[i]] <- entitydict[[i]][!duplicated(entitydict[[i]]$Name),]
}
 

#to incorporate manual disambiguation instructions,
#update manual_disambiguation_key.csv as desired and then
#turn on the toggle and run

if(manual_disambig == T){
  manual <- read.delim("salinasbox/clean_data/manual_disambiguation_key.txt")
  if(any(str_detect(manual$to, "Example"))){
    stop("The manual disambiguation key needs to be updated with real entity names before generating the disambiguated networks. After this is done, change the save filepath in the for loop below from example_only_cleaned_networks to manually_cleaned_networks")
  }
  
  for(i in seq_along(myextracts)){
    currentgroupname <- groupids$Group.Name[which(groupids$EIS.Number == names(myextracts)[i])]
    #we want to filter for only rows that are relevant for this project group
    current_manuals <- manual[str_squish(manual$Group.Name) == 
                                currentgroupname,]
    #now we combine the acronyms with the manual definitions to make
    #the to and from list that we put into the disambiguator
    if(length(current_manuals$from) > 0){
      from <- append(as.list(myacronyms[[i]]$from), as.list(current_manuals$from))
      to <- append(as.list(myacronyms[[i]]$to), stringr::str_split(current_manuals$to, "\\s*,\\s*"))
      
    }else{
      from <- as.list(myacronyms[[i]]$from)
      to <- as.list(myacronyms[[i]]$to)
    }
    print(i)
    source("code/part2_networkgeneration/helpers/disambig_helper.R")
    
    saveRDS(cleaned_extract, paste0("salinasbox/clean_data/example_only_cleaned_networks/cleanedextract_", names(myextracts)[i], ".RDS"))
  }
}else{
  for(i in seq_along(myextracts)){
    #we just use the project-specific acronyms 
    #and agency names from the list of known agencies
    #to make the to and from list 
    #that we put into the disambiguator
    from <- as.list(myacronyms[[i]]$from)
    to <- as.list(myacronyms[[i]]$to)
    print(i)
    source("code/part2_networkgeneration/helpers/disambig_helper.R")
    
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
