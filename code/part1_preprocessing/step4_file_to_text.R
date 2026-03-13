#Purpose: This script used pdftools to write the pdf to a txt file
#if the document is empty, it used ocr instead

#set-up: decide whether clobber is true or false,
#depending on whether you want to force overwrite files
CLOBBER <- FALSE  # Set this to TRUE if you want to overwrite existing txt files
source("code/config.R")
if (OVERWRITE_ALL) CLOBBER <- TRUE
packages <- c("pdftools", "data.table", "tesseract")

installed_packages <- rownames(installed.packages())

for (pkg in packages) {
  if (!pkg %in% installed_packages) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}
# PATH TO PDF FILES
pdf_file_directory <- "salinasbox/intermediate_data/pdfs_before_appendix_removal"

# We make a _raw_ conversion directory
# Next script then does filtering to a cleaned directory
txt_file_directory <- "salinasbox/intermediate_data/pdf_to_text_raw"

if (!dir.exists(txt_file_directory)) {
  dir.create(txt_file_directory)
}

pdfiles <- list.files(pdf_file_directory)

# Remove any PDFs whose ceqNumber is not in the study eisnums (e.g. stale files
# from previous runs or supplemental docs that were later excluded)
eisnums <- readLines("salinasbox/intermediate_data/solarwind_EISnumbers_V2.txt")
valid <- substr(pdfiles, 1, 8) %in% eisnums
if (any(!valid)) {
  message("Removing ", sum(!valid), " PDF(s) with ceqNumbers not in eisnums: ",
          paste(pdfiles[!valid], collapse = ", "))
  file.remove(file.path(pdf_file_directory, pdfiles[!valid]))
  pdfiles <- pdfiles[valid]
}

for (file in pdfiles) {
  txt_file_path <- file.path(txt_file_directory, sub("\\.pdf$", ".txt", file))
  if (file.exists(txt_file_path) && !CLOBBER) {
    next
  }
  tryCatch({
    #we suppressmessages according to documentation of pdftools since the function is extremely verbose
    text <- suppressMessages(pdf_text(file.path(pdf_file_directory, file)))
    # If the text is null or empty, use OCR to get the text
    if (is.null(text) || !any(nchar(unlist(text)) > 0)) {
      text <- suppressMessages(pdf_ocr_text(file.path(pdf_file_directory, file)))
    }
    # If the text is not null or empty, write it to the txt file    
    if (!is.null(text)) {
      dt <- data.table(page = seq_along(text), text = text)
      fwrite(dt, txt_file_path, sep = "\t")
    }
  }, error = function(e) {
    message(sprintf("Error processing file %s: %s", file, e$message))
  })
}
