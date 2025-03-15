library(findpython)
library(textNet)
ret_path <- find_python_cmd(required_modules = c('spacy', 'en_core_web_lg'))

bullettext <- vector(mode = "list", length = 1)
names(bullettext) <- "bullettest"
bullettext[[1]] <- "Monopile foundations with transition piece, or one-piece monopile/transition piece, where the transition piece is incorporated into the monopile \\n  • Foundation piles would be installed using a pile-driving hammer \\n  • Scour protection around all foundations"
bullettext[[1]] <- "Partners for this project include, The EPA\\n , DWR\\n , The Bureau of Land Management\\nand others."
bullettext[[1]] <- "The following agencies were invited to participate as cooperating
agencies for the Silver State Solar South Supplemental EIS/PRMPA and the Hidden Hills
Transmission Project EIS:
•   Advisory Council on Historic Preservation

•   Army Corps of Engineers

•   Bureau of Reclamation, Lower Colorado Regional Office

•   City of Boulder City"


myparsed <- textNet::parse_text(ret_path, 
                          keep_hyph_together = F,
                          parsed_filenames = "bullettest",
                          text_list = bullettext)

View(myparsed[[1]])



myparsed <- textNet::parse_text(ret_path, 
                                keep_hyph_together = F,
                                parsed_filenames = "bullettest",
                                text_list = bullettext)
