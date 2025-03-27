acrontable <- vector(mode = "list", length = length(rawtexts))
#for each project
for(i in 1:length(rawtexts)){
  shorts <- vector(mode = "character", length = 0)
  longs <- vector(mode = "character", length = 0)
  mysplits <- strsplit(rawtexts[[i]], "\\n")
  #for each page in project
  for(j in 1:length(mysplits)){
    #split on more than one space
    linesplits <- strsplit(mysplits[[j]], "\\s\\s+")
    #for each line in page
    if(length(linesplits)>0){
      for(k in 1:length(linesplits)){
        #remove any empty strings
        linesplits[[k]] <- linesplits[[k]][linesplits[[k]] != ""]
        #if there's nothing else on that line, just those two strings:
        if(length(linesplits[[k]]) == 2){
          #if the capital letters match and one of them has lowercase and the other has uppercase
          if(linesplits[[k]][1] == 
             stringr::str_remove_all(linesplits[[k]][2], "[a-z]|_|\\s") & 
             stringr::str_detect(linesplits[[k]][2], "[a-z]") &
             stringr::str_detect(linesplits[[k]][1], "[A-Z]")){
             shorts <- append(shorts, linesplits[[k]][1])
             longs <- append(longs, linesplits[[k]][2])
            #if the capital letters match and one of them has lowercase and the other has uppercase
          }else if(linesplits[[k]][2] == 
             stringr::str_remove_all(linesplits[[k]][1], "[a-z]|_|\\s") &
             stringr::str_detect(linesplits[[k]][1], "[a-z]") &
             stringr::str_detect(linesplits[[k]][2], "[A-Z]")){
             shorts <- append(shorts, linesplits[[k]][2])
             longs <- append(longs, linesplits[[k]][1])
          }
        }
      }
    }
    
  }
  acrontable[[i]] <- data.frame(name=character(length(longs)), acronym=character(length(longs)))
  acrontable[[i]]$name <- longs
  acrontable[[i]]$acronym <- shorts
}

#get rid of one-letter acronyms
for(i in 1:length(acrontable)){
  acrontable[[i]] <- acrontable[[i]][nchar(acrontable[[i]]$acronym)>1,]
  #replace non-word chars with underscore
  acrontable[[i]]$acronym <- str_replace_all(acrontable[[i]]$acronym, 
                                             "\\W", "_")
  acrontable[[i]]$name <- str_replace_all(acrontable[[i]]$name, 
                                             "\\W", "_")
}
names(acrontable) <- names(mytexts)
saveRDS(acrontable, "salinasbox/intermediate_data/partial_acronym_list_from_table_only.RDS")

