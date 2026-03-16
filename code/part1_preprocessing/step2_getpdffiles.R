#Purpose: Syncs pdfs_raw with the two PDF sources:
# 1. enepa_repository (primary, filtered via metadata whitelist)
# 2. supplemental_eis_documents (fallback for ceqNumbers with no enepa coverage)
# Removes any files in the destination not traceable to either source.

#Required setup: symbolic links to enepa Box ("../eis_documents") and salinas Box ("salinasbox")

#set-up: decide whether clobber is true or false,
#depending on whether you want to force overwrite files already in dest_dir
CLOBBER <- FALSE  # Set this to TRUE if you want to overwrite existing pdf files
source("code/config.R")
if (OVERWRITE_ALL) CLOBBER <- TRUE

library(arrow)
library(data.table)
library(stringr)

dest_dir      <- "salinasbox/intermediate_data/pdfs_raw"
pdf_directory <- "../eis_documents/enepa_repository/box_files/documents"
supp_dir      <- "salinasbox/supplemental_eis_documents/pdfs"

# --- Step 1: EIS numbers ---
eisnums <- read.table("salinasbox/intermediate_data/solarwind_EISnumbers_V2.txt", header = F)$V1

# --- Steps 2+3: Match doc_meta to eisnums, filter comment letters ---
doc_meta <- read_parquet("../eis_documents/enepa_repository/metadata/eis_document_record_api.parquet")
doc_meta$YEAR <- as.numeric(str_extract(doc_meta$ceqNumber, "^[0-9]{4}"))
doc_meta <- doc_meta[doc_meta$ceqNumber %in% eisnums & doc_meta$type != "Comment_Letter", ]
doc_meta <- data.table(doc_meta)
# Heuristic: files named exactly ceqNumber.pdf are misclassified EPA comment letters
doc_meta <- doc_meta[tools::file_path_sans_ext(name) != ceqNumber, ]

# Reconstruct expected PDF basenames from metadata
eis_stems      <- tools::file_path_sans_ext(doc_meta$fileNameForDownload)
eis_stems      <- gsub(" ",    "_", eis_stems)
eis_stems      <- gsub("[&)(]", "", eis_stems)
eis_basenames  <- gsub("_{2,}", "_", paste0(doc_meta$ceqNumber, "_", eis_stems, ".pdf"))

# Match to actual files in enepa pdf_directory
filelist       <- list.files(pdf_directory, recursive = TRUE)
matched_paths  <- filelist[basename(filelist) %in% eis_basenames]
matched_bases  <- basename(matched_paths)

# --- Step 4: Supplemental fallback for uncovered ceqNumbers ---
covered_eisnums  <- unique(substr(matched_bases, 1, 8))
fallback_eisnums <- eisnums[!eisnums %in% covered_eisnums]

supp_files   <- character(0)
still_missing <- character(0)
for (ceq in fallback_eisnums) {
  hits <- list.files(supp_dir, pattern = paste0("^", ceq, ".*\\.pdf$"), full.names = TRUE)
  if (length(hits) > 0) {
    supp_files <- c(supp_files, hits)
  } else {
    still_missing <- c(still_missing, ceq)
  }
}
saveRDS(still_missing, "salinasbox/intermediate_data/still_missing_eisnums.RDS")

# Full set of basenames that belong in dest_dir
expected_bases <- c(matched_bases, basename(supp_files))

# --- Step 5: Remove files in dest that are not from either source ---
current_files <- list.files(dest_dir)
to_remove     <- current_files[!current_files %in% expected_bases]
if (length(to_remove) > 0) {
  message("Removing ", length(to_remove), " file(s) not in either source:")
  message(paste(" ", to_remove, collapse = "\n"))
  file.remove(file.path(dest_dir, to_remove))
}

# --- Step 6: Copy source files into dest ---

# enepa PDFs
failedfiles <- character(0)
for (rel in matched_paths) {
  src <- file.path(pdf_directory, rel)
  dest_file <- file.path(dest_dir, basename(src))
  if (file.exists(dest_file) && !CLOBBER) next
  if (file.exists(src)) {
    file.copy(from = src, to = dest_file, overwrite = TRUE)
  } else {
    failedfiles <- c(failedfiles, rel)
    message("File not found in enepa repository: ", rel)
  }
}
saveRDS(failedfiles, "salinasbox/intermediate_data/failedfiles.RDS")

# Supplemental PDFs
for (src in supp_files) {
  dest_file <- file.path(dest_dir, basename(src))
  if (file.exists(dest_file) && !CLOBBER) next
  file.copy(from = src, to = dest_file, overwrite = TRUE)
}
