
packages <- c("data.table")

installed_packages <- rownames(installed.packages())

for (pkg in packages) {
  if (!pkg %in% installed_packages) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}
# INSERT DIRECTORY PATHS HERE
raw_text_directory <- "[DIRECTORY HERE]"
clean_text_directory <- "[DIRECTORY HERE]"

raw_text_files <- list.files(raw_text_directory, pattern = "\\.csv$", full.names = TRUE)
clean_text_files <- list.files(clean_text_directory, pattern = "\\.csv$", full.names = TRUE)

raw_file_names <- basename(raw_text_files)
clean_file_names <- basename(clean_text_files)

common_files <- intersect(raw_file_names, clean_file_names)

missing_pages <- list()

for (file_name in common_files) {
  raw_file_path <- file.path(raw_text_directory, file_name)
  clean_file_path <- file.path(clean_text_directory, file_name)
  
  raw_data <- fread(raw_file_path)
  clean_data <- fread(clean_file_path)
  
  if ("page" %in% colnames(raw_data) && "page" %in% colnames(clean_data)) {
    missing_pages[[file_name]] <- setdiff(raw_data$page, clean_data$page)
  }
}

print(missing_pages)
