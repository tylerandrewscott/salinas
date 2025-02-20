
packages <- c("pdftools", "data.table")

installed_packages <- rownames(installed.packages())

for (pkg in packages) {
  if (!pkg %in% installed_packages) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}
# INSERT DIRECTORY PATHS HERE
pdf_directory <- "[DIRECTORY HERE]"
raw_text_directory <- "[DIRECTORY HERE]"
clean_text_directory <- "[DIRECTORY HERE]"

pdf_files <- list.files(pdf_directory, pattern = "\\.pdf$", full.names = TRUE)
pdf_info_list <- lapply(pdf_files, pdf_info)
pdf_page_counts <- sapply(pdf_info_list, function(info) info$pages)
names(pdf_page_counts) <- basename(pdf_files)

raw_text_files <- list.files(raw_text_directory, pattern = "\\.csv$", full.names = TRUE)
raw_row_counts <- sapply(raw_text_files, function(file) {
  dt <- fread(file)
  nrow(dt)
})
names(raw_row_counts) <- basename(raw_text_files)

clean_text_files <- list.files(clean_text_directory, pattern = "\\.csv$", full.names = TRUE)
clean_row_counts <- sapply(clean_text_files, function(file) {
  dt <- fread(file)
  nrow(dt)
})
names(clean_row_counts) <- basename(clean_text_files)

all_file_names <- unique(c(names(pdf_page_counts), names(raw_row_counts), names(clean_row_counts)))

result_df <- data.frame(
  FileName = all_file_names,
  PDF_Page_Count = pdf_page_counts[all_file_names],
  Raw_Row_Count = raw_row_counts[all_file_names],
  Clean_Row_Count = clean_row_counts[all_file_names],
  stringsAsFactors = FALSE
)

print(result_df)
