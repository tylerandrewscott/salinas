#Purpose: This script cleans the raw .txt files of non-prose pages 
#like maps, tables, etc. by
#setting a threshold for each page of: 
#max characters, punctuation, numeric characters, and white space
#past which it sets page text to NA
#Headers and footers are also removed here

#Set-up: Decide whether clobber (overwrite files) = T or F.
CLOBBER <- T

packages <- c("data.table", "stringr", "dplyr")

installed_packages <- rownames(installed.packages())

for (pkg in packages) {
  if (!pkg %in% installed_packages) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}

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

for (file in raw_files) {
  
  cleaned_file <- file.path(cleaned_txt_file_location, basename(file))
  if (CLOBBER || !file.exists(cleaned_file)) {
    data <- fread(file)
    # Calculate total characters for each text entry once
    total_characters <- nchar(data$text)
     
    # Filter out pages with excessive punctuation, numeric characters, or too many total characters
    punctuation_count <- str_count(data$text, "[[:punct:]]")
    numeric_character_count <- str_count(data$text, "[0-9]")
    white_space_count <- str_count(data$text, "\\s")
    
    punctuation_density <- punctuation_count / total_characters
    numeric_character_density <- numeric_character_count / total_characters
    white_space_density <- white_space_count / total_characters
    
    #use these vars to manually check examples of failed pages to make sure threshold is sensible
    #punctfail for the first and second file is only references and table of contents
    punctfail <- data[punctuation_density > punctuation_density_threshold, ]
    #numfail for the first file is empty. threshold of 0.1 catches partial tables
    #for file 1 and 0.15 catches partial tables for file 2 so 0.25 seems reasonable
    #for file 3, 0.05 catches references
    numfail <- data[numeric_character_density > numeric_character_density_threshold, ]
    #spacefail for the first file is only tables
    spacefail <- data[white_space_density > white_space_density_threshold, ]
    #charfail for the first file is empty, for file 2 is a bunch of maps
    charfail <- data[total_characters > max_characters, ]
    #thresholds are suitable for not removing true sentences.
    
    #instead of cutting pages we just set them to an empty string.
    #That way it's easier to query by page number and match network
    #data to the original pdf
    
    data$text <- case_when(
      total_characters == 0 ~ "",
      punctuation_density > punctuation_density_threshold |
        numeric_character_density > numeric_character_density_threshold |
        white_space_density > white_space_density_threshold | 
        total_characters > max_characters ~ "",
      T ~ data$text
    )

    removed <- headfootremove(data$text, option = "first_six_lines")
    
    cleanlength <- unlist(lapply(removed, function(i) nchar(i)))
    rawlength <- unlist(lapply(data$text, function(i) nchar(i)))
    rawlength - cleanlength
    
    #let's look at headers and footers that were removed
    #as a check
    headersfooters <- sapply(seq_along(1:length(cleanlength)), function(i){
      if(is.na(removed[i]) | nchar(removed[i]) > 0){
        str_remove(data$text[i], coll(removed[i]))
      }else{
        data$text[i]
      }
      
    })
    
    #removal of certain pages as described in salinasbox/intermediate_data/appendix_removal/!README.docx
    #remove page 214 onward of the 20140004_Fowler_Ridge_Wind_Farm_Final_EIS_010714
    #since it is appendices
    if(basename(file) == "20140004_Fowler_Ridge_Wind_Farm_Final_EIS_010714.txt"){
      data <- data[1:213,]
    }
    
    fwrite(data, cleaned_file)
  }
}
