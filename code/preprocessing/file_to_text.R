

packages <- c("pdftools", "data.table", "tesseract")

installed_packages <- rownames(installed.packages())

for (pkg in packages) {
  if (!pkg %in% installed_packages) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}
# INSERT PATH TO PDF FILES HERE
pdf_file_directory <- "[PATH TO PDF FILES]"

# I suggest making a _raw_ conversion directory
# Next script can then do filtering to a cleaned directory
txt_file_directory <- "[PATH TO TXT FILES]"

if (!dir.exists(txt_file_directory)) {
  dir.create(txt_file_directory)
}

pdfiles <- list.files(pdf_file_directory)

CLOBBER <- FALSE  # Set this to TRUE if you want to overwrite existing txt files

for (file in pdfiles) {
  txt_file_path <- file.path(txt_file_directory, sub("\\.pdf$", ".txt", file))
  if (file.exists(txt_file_path) && !CLOBBER) {
    next
  }
  tryCatch({
    text <- pdf_text(file.path(pdf_file_directory, file))
    # If the text is null or empty, use OCR to get the text
    if (is.null(text) || !any(nchar(unlist(text)) > 0)) {
      text <- pdf_ocr_text(file.path(pdf_file_directory, file))
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
