matched_projects <- read.table(file = 'salinasbox/intermediate_data/matched_pdf_list.tsv', sep = '\t', header = F)
matched_projects$V1 <- stringr::str_remove(matched_projects$V1, "Users/elisemiller/R_Projects/salinas/text_as_datatable/")
