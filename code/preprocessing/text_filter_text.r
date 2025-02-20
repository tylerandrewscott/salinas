
packages <- c("data.table", "stringr")

installed_packages <- rownames(installed.packages())

for (pkg in packages) {
  if (!pkg %in% installed_packages) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}

raw_txt_file_location <- "[FILE DIR HERE]"

cleaned_txt_file_location <- "[FILE DIR HERE]"
if (!dir.exists(cleaned_txt_file_location)) {
  dir.create(cleaned_txt_file_location)
}

CLOBBER <- TRUE

# what are maximum proportions of characters are punctuation, numeric characters, or white space?
# if want to turn off, set to 1 (i.e., keep all because ratio cannot be > 1)
punctuation_density_threshold <- 0.1
numeric_character_density_threshold <- 0.25
white_space_density_threshold <- 0.8

# what is the maximum number of characters in page?
# (20k is pretty generous)
max_characters = 20e3

raw_files <- list.files(raw_txt_file_location, full.names = TRUE)

for (file in raw_files) {
  cleaned_file <- file.path(cleaned_txt_file_location, basename(file))
  if (CLOBBER || !file.exists(cleaned_file)) {
    data <- fread(file)
    # Calculate total characters for each text entry once
    total_characters <- nchar(data$text)
     
    # Filter out files with excessive punctuation, numeric characters, or too many total characters
    punctuation_count <- str_count(data$text, "[[:punct:]]")
    numeric_character_count <- str_count(data$text, "[0-9]")
    white_space_count <- str_count(data$text, "\\s")
    
    punctuation_density <- punctuation_count / total_characters
    numeric_character_density <- numeric_character_count / total_characters
    white_space_density <- white_space_count / total_characters
    
    data <- data[!(punctuation_density > punctuation_density_threshold | 
                   numeric_character_density > numeric_character_density_threshold | 
                   white_space_density > white_space_density_threshold | 
                   total_characters > max_characters)]

    fwrite(data, cleaned_file)
  }
}
