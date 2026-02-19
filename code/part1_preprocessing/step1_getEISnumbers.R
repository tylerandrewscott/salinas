#Purpose: We used this script in a remote copy of the eis_documents github project
#to filter the metadata records to extract solar and wind projects that are
#candidates for the study and save the subset as an RDS and extract a list of 
#the corresponding EIS numbers

#Required Setup: clone the eis_documents github repository and use this script from
#the remote.
#Next set up symbolic link to salinas Box as "salinasbox"

library(stringr)
library(arrow)
#docrecords <- readRDS("../eis_documents/enepa_repository/metadata/eis_document_record.rds")
docrecords <- read_parquet("../eis_documents/enepa_repository/metadata/eis_document_record_api.parquet")
#recorddeets <- readRDS("enepa_repository/metadata/eis_record_detail.rds")
recorddeets <- read_parquet("../eis_documents/enepa_repository/metadata/eis_record_api.parquet")
#filter for only solar and wind projects by matching on words "solar" and "wind"
#excludes references to "wind river", "wind cave", "wind damage", "wind tunnel",
#excludes references to "solar system", "solar telescope"
#does include "cape wind" since this is an energy project

solarwinddeets <- recorddeets[str_detect(recorddeets$title,
                                         "(S|s)olar(?!\\sSystem|\\sTelescope)|(W|w)ind\\s(?!(R|r)iver|(C|c)ave|(D|d)amage|(T|t)unnel)|(W|w)ind$"),]

saveRDS(solarwinddeets, "salinasbox/solarwind_project_details_V2.RDS")
#solarwinddeets <- readRDS("salinasbox/solarwind_project_details.RDS")
writeLines(as.character(solarwinddeets$ceqNumber), "salinasbox/intermediate_data/solarwind_EISnumbers_V2.txt")

#test <- readLines("salinasbox/intermediate_data/solarwind_EISnumbers.txt")
#table(test %in% solarwinddeets$ceqNumber)
#solarwinddeets$ceqNumber[!solarwinddeets$ceqNumber %in% test]
