library(stringr)
docrecords <- readRDS("enepa_repository/metadata/eis_document_record.rds")
recorddeets <- readRDS("enepa_repository/metadata/eis_record_detail.rds")
#filter for only solar and wind projects by matching on words "solar" and "wind"
#excludes references to "wind river"
#excludes references to "wind cave"
#excludes references to "wind damage"
#excludes reference to "wind tunnel"
#excludes references to "solar system"
#excludes references to "solar telescope"
#does include "cape wind" since this is an energy project
recorddeets[str_detect(recorddeets$Title, "Solar(?=\\sSystem|\\sTelescope)"),]$Title

solarwinddeets <- recorddeets[str_detect(recorddeets$Title,
                                         "(S|s)olar(?!\\sSystem|\\sTelescope)|(W|w)ind\\s(?!(R|r)iver|(C|c)ave|(D|d)amage|(T|t)unnel)|(W|w)ind$"),]

saveRDS(solarwinddeets, "salinasbox/solarwind_project_details.RDS")
energydeets <- recorddeets[str_detect(recorddeets$Title,
                                      "Energy") & !str_detect(recorddeets$Title,
                                                              "Wind|Solar"),]


solarwindpublic <- solarwinddeets[solarwinddeets$Agency %in%
                                    c("Bureau of Land Management",
                                      "Forest Service",
                                      "National Park Service",
                                      "Fish and Wildlife Service"),]

solarwinddeets <- readRDS("salinasbox/solarwind_project_details.RDS")
writeLines(as.character(solarwinddeets$EIS.Number), "solarwind_EISnumbers.txt")
#energy project
#energy development

#condon wind project transmission services agreements
#250-MW coal fired power plant and 6MW of wind generation