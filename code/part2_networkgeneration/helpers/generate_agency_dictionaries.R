#I imagine at some point it would be helpful to go through and
#replace spacy's best guess at entity_type with a more 
#educated approach based on our expert knowledge. 
#this classification doesn't need to be comprehensive encompassing every node 
#(that wouldn't really be feasible within the scope of this project)
#but rather we can highlight certain categories of nodes we care about
#based on parsimonious lists/dictionaries

#most_other_states is imported from govscienceuseR
#and fed_and_CA_agencies is imported from kings Github. 
#CA agency abbreviations are all filled out because Elise did this by hand
#for the kings project. Since we also used find_acronyms on each doc,
#it should be relatively fine that the other state agencies are not 
#fully populated with their abbreviations

#these six states were missing for some reason from the most_other_states file
#supplemented as follows:
#kentucky agencies from https://www.kentucky.gov/government/pages/agency.aspx
#illinois agencies from Illinois Secretary of State (https://www.ilsos.gov/services/illinks.html)
#michigan agencies from https://www.michigan.gov/som/government/branches-of-government
#missouri agencies from https://www.mo.gov/search-results?mode=state_agencies
#west virginia agencies from https://www.wv.gov/agencies/Pages/default.aspx
#wisconsin agencies from https://www.wisconsin.gov/pages/allagencies.aspx
library(stringr)
library(data.table)
library(dplyr)
library(textNet)

sixstatefiles <- list.files("salinasbox/raw_data/agency_databases", pattern = "_stategov", full.names = T)

sixstates <- lapply(sixstatefiles, function(i) {
  as.data.frame(read.csv(i)[,"agencyname"])
  })
names(sixstates) <- str_remove(basename(sixstatefiles), "_.*")
sixstates <- rbindlist(sixstates, idcol = "State")
most_other_states <- readRDS("salinasbox/raw_data/agency_databases/govscienceuseR_agencies.RDS")
most_other_states <- most_other_states[!most_other_states$State %in% c("California", "federal"),]
fed_and_CA <- read.csv("salinasbox/raw_data/agency_databases/govsci_tbl_clean.csv")

#formatting cleanup so they're all the same
sixstates$Abbr <- ""
colnames(sixstates)[colnames(sixstates)=="read.csv(i)[, \"agencyname\"]"] <- "Agency"
fed_and_CA$X <- NULL

all_agencies <- rbindlist(list(sixstates, most_other_states, fed_and_CA))

#little bit of hand cleaning
all_agencies$Agency[str_detect(all_agencies$Agency, "Fraud") &
              str_detect(all_agencies$State, "Arkansas")] <- 
  "Arkansas Department of Commerce Fraud, Investigation, Recovery, & Enforcement Department"
all_agencies <- all_agencies[!str_detect(all_agencies$Agency, "#NAME?"),]
all_agencies$Agency <- ifelse(str_detect(all_agencies$Agency, "Alabama : Alabama"),
                              str_remove(all_agencies$Agency, "Alabama : "),
                              all_agencies$Agency)
#this lack of spacing is a cue of a misapplied automated process
all_agencies$Agency <- case_when(
  str_detect(all_agencies$Agency, "[a-z](Department|Commission|council|Board)$") ~
    str_remove(all_agencies$Agency, "(Department|Commission|council|Board)$"),
  T ~ all_agencies$Agency
)

all_agencies$Agency <- str_remove(all_agencies$Agency, '^The\\s')
#remove local agencies and random acronyms held over from kings project
all_agencies <- all_agencies[!all_agencies$State %in% c("local", ""),]

org_words <- c("Administration", "Agency", "Association", "Associates", "Authority",  
               "Board", "Bureau", "Center", "^Consult[a-z]+$",
               "Commission", "Council", "County",  "Department", "Datacenter", "District", "Division", 
               "Foundation", "Government[s]*", "Group", 
               "Institute", "LLC", "Laboratory", "Office", "Service", "Society", "Survey",  
               "Univeristy")
org_phrases <- as.vector(outer(org_words, c("of","on","for"), paste, sep = " "))
org_phrases <- paste(org_phrases, collapse = "|")

spl <- strsplit(all_agencies$Agency, ',\\s*')

orgs_reordered <- sapply(1:length(spl), function (x) {
  #if one of splits (opt: besides the first one) has an org word followed by "of" or "for" 
  if(sum(grepl(org_phrases, spl[[x]]))>0){
    #then move all of the following splits to the beginning:
    #find first match: grep(org_phrases, x)[1]
    #and put all the elements after that at the front of the vector
    sorted <- c(spl[[x]][grep(org_phrases, spl[[x]])[1]:length(spl[[x]])], spl[[x]][-(grep(org_phrases, spl[[x]])[1]:length(spl[[x]]))])
    #combine the first two elements so there's no comma after "of" / "for" / "on"
    if(length(sorted)>1){
      sorted <- c(paste(sorted[1],sorted[2]), sorted[-(1:2)])
    }
    sorted
  }else{spl[[x]]
  }
})


orgs_with_commas <- sapply(orgs_reordered, function (x) {paste(x, collapse = ", ")})

orgs_underscore <- sapply(strsplit(orgs_with_commas,',*\\s+'), function(x) paste(x, collapse = "_"))

all_agencies$Agency <- orgs_underscore

statenames <- unique(all_agencies$State)
statenames <- statenames[!statenames %in% c("federal")]

#add abbrevs from agency name
possibleabbrevs <- str_remove(str_remove(all_agencies$Agency, ".*\\("),"\\)")
#possibleabbrevs[!str_detect(possibleabbrevs, "[a-z]")]

all_agencies$Abbr <- dplyr::case_when(
  all_agencies$Abbr != "" ~ all_agencies$Abbr,
  !str_detect(possibleabbrevs, "[a-z]") ~ possibleabbrevs,
  all_agencies$Abbr == "" ~ ""
)

#turning all remaining non-word (letter and number) characters into underscores
all_agencies$Abbr <- str_replace_all(all_agencies$Abbr, "\\W+", "_")
all_agencies$Agency <- str_replace_all(all_agencies$Agency, "\\W+", "_")
#collapsing consecutive underscores
all_agencies$Abbr <- str_replace_all(all_agencies$Abbr, "_+", "_")
all_agencies$Agency <- str_replace_all(all_agencies$Agency, "_+", "_")

#Agency should have the state's name in front of it
#Abbr filled in with agency name without the state's name in front of it
#note that these are not necessarily unique, as multiple states have a "Court of Appeals", etc.
#the disambiguate function will automatically not use any ambiguous/duplicated rules,
#so that is not a problem there, but should be noted 
#
all_agencies$NameWithoutState <- unlist(lapply(1:nrow(all_agencies), function(i){
  dplyr::case_when(
    #if it's a federal agency, remove the preceding "Federal" or "US"
    all_agencies$State[i] == "federal" ~ str_remove(all_agencies$Agency[i], paste0("^(F|f)ederal_|^US_|^U.S._|^United States")),
    #otherwise remove the state name
    str_detect(all_agencies$Agency[i], str_replace_all(all_agencies$State[i], " ", "_")) ~ str_remove(all_agencies$Agency[i], paste0("^", str_replace_all(all_agencies$State[i], " ", "_"), "_")),
    T ~ all_agencies$Agency[i]
  )
}))

all_agencies$NameWithState <- unlist(lapply(1:nrow(all_agencies), function(i){
  dplyr::case_when(
    #if it's a federal agency and it doesn't have "Federal" or "US" in front of it, add "US"
    all_agencies$State[i] == "federal" & !str_detect(all_agencies$Agency[i], "^(f|F)ederal_|^US_|^U.S._|^United States") ~ paste0("US_", all_agencies$Agency[i]),
    #if it's a federal agency and it does have "Federal" or "US" in front of it, leave it be
    all_agencies$State[i] == "federal" & str_detect(all_agencies$Agency[i], "^(f|F)ederal_|^US_|^U.S._|^United States") ~ all_agencies$Agency[i],
    #if it's a state agency, put the preceding state name on it
    str_detect(all_agencies$Agency[i], str_replace_all(all_agencies$State[i], " ", "_"), negate = T) ~ paste0(str_replace_all(all_agencies$State[i], " ", "_"), "_", all_agencies$Agency[i]),
    T ~ all_agencies$Agency[i]
  )
}))

key <- all_agencies |> select(State, NameWithoutState, NameWithState) 
key <- key[!duplicated(key),]
key <- key |> group_by(NameWithState) |> mutate(NameWithStatePopularity = n())
key <- key |> ungroup() |> group_by(NameWithoutState) |> mutate(NameWithoutStatePopularity = n())

all_agencies <- full_join(all_agencies, key)
#let's keep with state name and without state name as two separate columns
all_agencies$Agency <- NULL
#sort alphabetically
all_agencies <- all_agencies[order(all_agencies$State),]

for_disambig <- all_agencies
#if abbr is the same as name without state or name with state, set it to blank
for_disambig$Abbr <- ifelse(for_disambig$Abbr == for_disambig$NameWithoutState |
                              for_disambig$Abbr == for_disambig$NameWithState,
                            "", for_disambig$Abbr)

noabbr <- for_disambig %>% filter(is.na(Abbr) | nchar(Abbr) == 0)
yesabbr <- for_disambig %>% filter(!is.na(Abbr) & nchar(Abbr) != 0)

#if there are rows with no abbr for orgs that do have valid abbrs, remove those rows
noabbr <- noabbr[!(noabbr$NameWithoutState %in% yesabbr$NameWithoutState),]

#for the disambiguator we want a file that maps all abbreviations
#and NameWithoutState to the NameWithState
#we will later have a helper that ensures uniqueness and subsets by state
for_disambig <- rbind(yesabbr, noabbr)
for_disambig <- for_disambig |> dplyr::select(-c("NameWithoutStatePopularity",
                                                 "NameWithStatePopularity"))
for_disambig$UnitedStates <- str_replace(for_disambig$NameWithState, 
                                         "^US_", "United_States_")
#also account for orgs that say "United States" instead of "US" at beginning
for_disambig$UnitedStates <- dplyr::case_when(
  str_detect(for_disambig$UnitedStates, "^United_States_") ~ for_disambig$UnitedStates,
  T ~ ""
)

for_disambig <- tidyr::pivot_longer(for_disambig,
                             cols = c("Abbr",
                                             "NameWithoutState",
                                      "UnitedStates"),
                             values_to = "from")
for_disambig$to <- for_disambig$NameWithState
for_disambig <- for_disambig |> dplyr::select("from", "to", "State")
for_disambig <- for_disambig |> dplyr::filter(from != "" & to!="")

#reorder for_disambig so that federal agencies are at the top
#because this influences the duplication removal preference later on
for_disambig <- rbind(for_disambig[for_disambig$State == "federal",],
                      for_disambig[for_disambig$State != "federal",])

for_disambig <- unique(for_disambig)

saveRDS(for_disambig, "salinasbox/intermediate_data/agencylist_for_disambiguation.RDS")
#for the dictionary we want a file that maps the official name to the State name
#since we will have already completed the disambiguation we don't need to
#keep the unofficial names
for_entity_dictionary <- all_agencies |> dplyr::select(-c("NameWithoutStatePopularity",
                                                          "NameWithStatePopularity"))

for_entity_dictionary <- tidyr::pivot_longer(for_entity_dictionary,
                                    cols = c("Abbr",
                                             "NameWithoutState", "NameWithState"),
                                    values_to = "Name", 
                                    names_to = "Type")
for_entity_dictionary <- for_entity_dictionary |> 
  dplyr::filter(Type != "" & Name!="")

#reorder for_entity_dictionary so that federal agencies are at the top
#because this influences the duplication removal preference later on
for_entity_dictionary <- rbind(for_entity_dictionary[for_entity_dictionary$State == "federal",],
                               for_entity_dictionary[for_entity_dictionary$State != "federal",])


for_entity_dictionary$Name <- tolower(textNet::clean_entities(for_entity_dictionary$Name))
for_entity_dictionary <- for_entity_dictionary[for_entity_dictionary$Name!="",]
saveRDS(for_entity_dictionary, "salinasbox/intermediate_data/agencylist_for_entitydictionary.RDS")


