#Purpose: This script is a process check to make sure the page count
#for the clean files looks good. 

#Setup: None

packages <- c("pdftools", "data.table", "stringr")

installed_packages <- rownames(installed.packages())

for (pkg in packages) {
  if (!pkg %in% installed_packages) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}

pdf_directory <- "salinasbox/intermediate_data/appendix_removal/done"
raw_text_directory <- "salinasbox/intermediate_data/pdf_to_text_raw"
clean_text_directory <- "salinasbox/clean_data/pdf_to_text_clean"

pdf_files <- list.files(pdf_directory, pattern = "\\.pdf$", full.names = TRUE)
pdf_info_list <- lapply(pdf_files, pdf_info)
pdf_page_counts <- sapply(pdf_info_list, function(info) info$pages)
names(pdf_page_counts) <- basename(pdf_files)

raw_text_files <- list.files(raw_text_directory, pattern = "\\.txt$", full.names = TRUE)
raw_row_counts <- sapply(raw_text_files, function(file) {
  dt <- fread(file)
  nrow(dt)
})
raw_num_empties <- sapply(raw_text_files, function(file) {
  dt <- fread(file)
  sum(str_equal(dt$text, ""))
})
names(raw_row_counts) <- basename(raw_text_files)

clean_text_files <- list.files(clean_text_directory, pattern = "\\.RDS$", full.names = TRUE)
clean_row_counts <- sapply(clean_text_files, function(file) {
  dt <- readRDS(file)
  nrow(dt)
})
clean_num_empties <- sapply(clean_text_files, function(file) {
  dt <- readRDS(file)
  dt$text <- case_when(is.na(dt$text) ~ "",
            T ~ dt$text)
  sum(str_equal(dt$text, ""))
})
names(clean_row_counts) <- basename(clean_text_files)

all_file_names <- str_remove(names(pdf_page_counts),".pdf$")
#check that pdf order = same as txt order. should be sum of 0
sum(all_file_names != str_remove(names(raw_row_counts),".txt$"))

result_df <- data.frame(
  FileName = all_file_names,
  PDF_Page_Count = unname(pdf_page_counts),
  Raw_Row_Count = unname(raw_row_counts),
  #num empty pages in raw
  Raw_Num_Empties = raw_num_empties,
  Clean_Row_Count = unname(clean_row_counts),
  #num empty pages in cleaned version
  #poorly formatted pages were turned into empty strings
  Clean_Num_Empties = clean_num_empties,
  stringsAsFactors = FALSE
)

saveRDS(result_df, "salinasbox/clean_data/page_count_comparison.RDS")
View(result_df)
