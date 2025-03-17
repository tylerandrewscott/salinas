#Purpose: This script cleans the raw .txt files of non-prose pages 
#like maps, tables, etc. by
#setting a threshold for each page of: 
#max characters, punctuation, numeric characters, and white space
#past which it sets page text to NA
#Headers and footers are also removed here

#Set-up: Decide whether clobber (overwrite files) = T or F.
#Also, there are a few quality tests to verify header/footer removal functionality
#To run these, set runtests = T and visually inspect the output
CLOBBER <- T
runtests = F

packages <- c("data.table", "stringr", "dplyr")
installed_packages <- rownames(installed.packages())
for (pkg in packages) {
  if (!pkg %in% installed_packages) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}

source("code/part1_preprocessing/helpers/headfootremove.R")

raw_txt_file_location <- "salinasbox/intermediate_data/pdf_to_text_raw"

cleaned_txt_file_location <- "salinasbox/clean_data/pdf_to_text_clean"
if (!dir.exists(cleaned_txt_file_location)) {
  dir.create(cleaned_txt_file_location)
}

raw_files <- list.files(raw_txt_file_location, full.names = TRUE)

#These thresholds were set for this project based on testing of samples
# what are maximum proportions of characters are punctuation, numeric characters, or white space?
# if want to turn off, set to 1 (i.e., keep all because ratio cannot be > 1)
punctuation_density_threshold <- 0.1
numeric_character_density_threshold <- 0.25
white_space_density_threshold <- 0.75
# what is the maximum number of characters in page?
# (20k is pretty generous)
max_characters = 20e3
data <- vector(mode = "list", length = length(raw_files))
dataraw <- vector(mode = "list", length = length(raw_files))
dataintermed <- vector(mode = "list", length = length(raw_files))
for (x in seq_along(raw_files)) {
  
  cleaned_file <- file.path(cleaned_txt_file_location, 
                            stringr::str_replace(basename(raw_files[x]), ".txt$", ".RDS"))
  if (CLOBBER || !file.exists(cleaned_file)) {
    data[[x]] <- fread(raw_files[x])
    dataintermed[[x]] <- fread(raw_files[x])
    dataraw[[x]] <- fread(raw_files[x])
    # Calculate total characters for each text entry once
    total_characters <- nchar(data[[x]]$text)
     
    # Filter out pages with excessive punctuation, numeric characters, or too many total characters
    punctuation_count <- str_count(data[[x]]$text, "[[:punct:]]")
    numeric_character_count <- str_count(data[[x]]$text, "[0-9]")
    white_space_count <- str_count(data[[x]]$text, "\\s")
    
    punctuation_density <- punctuation_count / total_characters
    numeric_character_density <- numeric_character_count / total_characters
    white_space_density <- white_space_count / total_characters
    
    #use these vars to manually check examples of failed pages to make sure threshold is sensible
    #punctfail for the first and second file is only references and table of contents
    punctfail <- data[[x]][punctuation_density > punctuation_density_threshold, ]
    #numfail for the first file is empty. threshold of 0.1 catches partial tables
    #for file 1 and 0.15 catches partial tables for file 2 so 0.25 seems reasonable
    #for file 3, 0.05 catches references
    numfail <- data[[x]][numeric_character_density > numeric_character_density_threshold, ]
    #spacefail for the first file is only tables
    spacefail <- data[[x]][white_space_density > white_space_density_threshold, ]
    #charfail for the first file is empty, for file 2 is a bunch of maps
    charfail <- data[[x]][total_characters > max_characters, ]
    #thresholds are suitable for not removing true sentences.
    
    #instead of cutting pages we just set them to an empty string.
    #That way it's easier to query by page number and match network
    #data to the original pdf
    
    data[[x]]$text <- case_when(
      total_characters == 0 ~ "",
      punctuation_density > punctuation_density_threshold |
        numeric_character_density > numeric_character_density_threshold |
        white_space_density > white_space_density_threshold | 
        total_characters > max_characters ~ "",
      T ~ data[[x]]$text
    )
    print(raw_files[x])
    dataintermed[[x]]$text <- data[[x]]$text
    data[[x]]$text <- headfootremove(data[[x]]$text)
    
    #removal of certain pages as described in salinasbox/intermediate_data/appendix_removal/!README.docx
    #remove page 214 onward of the 20140004_Fowler_Ridge_Wind_Farm_Final_EIS_010714
    #since it is appendices
    if(basename(raw_files[x]) == "20140004_Fowler_Ridge_Wind_Farm_Final_EIS_010714.txt"){
      data[[x]] <- data[[x]][1:213,]
    }
    #keep in RDS rather than txt for encoding ease
    #this is important because we want to compare the header/footer removal to make sure it works acceptably
    saveRDS(object = data[[x]], file = cleaned_file)
  }
}
saveRDS(object = data, file = "salinasbox/clean_data/all_clean_texts_pregrouping.RDS")

#the rest of this script consists of tests to verify
#quality of the header/footer removal
#use the switch at the top of the script to turn this on or off
if(runtests==T){
  
  #let's make a list of the header/footer content that got removed
  difs <- vector(mode = "list", length = length(raw_files))
  for(i in seq_along(raw_files)){
    #if you want to compare with totally raw, use raw <- dataraw[[i]]
    #I am specifically interested in what happened with the 
    #header/footer removal so I am using raw <- dataintermed[[i]]
    raw <- dataintermed[[i]]
    clean <- data[[i]]
    
    difs[[i]] <- sapply(1:nrow(raw), function(j){
      #this gives a warning but we have set this up to not match on
      #empty coll strings so we can suppress warnings
      suppressWarnings(dplyr::case_when(
        #no dif because original is blank
        is.na(raw$text[j]) ~ "",
        nchar(raw$text[j]) == 0 ~ "",
        #dif = raw because clean is blank
        is.na(clean$text[j]) ~ raw$text[j],
        nchar(coll(clean$text[j])) == 0 ~ raw$text[j],
        nchar(coll(clean$text[j])) > 0 ~ str_replace(raw$text[j], coll(clean$text[j]), "####"),
        T ~ "edgecase"
      ))
    })
  }
  
  #look for stuff where there is no difference, to make sure it isn't
  #categorically missing a certain type of header/footer
  #good; it just happens on pages that were already empty in dataintermed
  for(i in 1:length(difs)){
    print(dataintermed[[i]]$text[is.na(difs[[i]])|nchar(difs[[i]])==0])
  }
  #even though there's never zero difference, it's possible it 
  #just removes the page number and that's it. Let's look at those
  #cases too just to do a visual inspection and make sure 
  #there aren't headers/footers that were systematically missed
  #looks fine. a couple of page nums formatted as "1-3" are missed
  #but these do not impact the network
  for(i in 1:length(difs)){
    print(data[[i]]$text[!is.na(difs[[i]])&nchar(difs[[i]])<6])
  }
  
  #look for long header/footers that got removed
  #these look good, it's nearly exclusively either tables or references
  #I exclude the 20140004 plan from this analysis because a bunch of appendix
  #pages got removed but that's not because of the header/footer tool
  for(i in c(1:40,42:length(difs))){
    print(paste0(i, "XXXXXX"))
    print(difs[[i]][!is.na(difs[[i]]) & nchar(difs[[i]])>600])
  }
  
  #look for when the raw plan page was not empty but the clean plan page is
  #try this on an example plan to make sure no important things are getting lost
  #looks good; just a bunch of figure captions and tables
  i <- 30 #choose a number representing an example plan
  sampleplan <- dataintermed[[i]]
  sampleclean <- data[[i]]
  nas <- sapply(1:nrow(sampleplan), function(j){
    if((is.na(sampleclean$text[j])|nchar(sampleclean$text[j])==0) & 
       !is.na(sampleplan$text[j])){
      sampleplan$text[j]
    }else{
      ""
    }})
  unlist(nas)
}
