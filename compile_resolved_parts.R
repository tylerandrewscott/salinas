#projectname <- '20130260_Moapa_Solar_Energy_Center_Draft_EIS_-_Volume_2_Appendices_\\(8-28-13\\)_Bookmark_View'
#parts <- list.files(path = '../salinas/openai_output_files', pattern = paste0(projectname,"\\'_part[0-9]*\\.txt"), full.names = T)
#orderofparts <- stringr::str_remove(parts, paste0("\\.\\./salinas/openai_output_files\\/b\\'",projectname,"\\'_part"))

projectname <- '20130221_PSEGS_DSEIS_Volume_1'
parts <- list.files(path = '../salinas/openai_output_files', pattern = paste0(projectname,"_part[0-9]*\\.txt"), full.names = T)
orderofparts <- stringr::str_remove(parts, paste0("\\.\\./salinas/openai_output_files\\/",projectname,"_part"))


orderofparts <- stringr::str_remove(orderofparts, ".txt")
orderofparts <- as.numeric(orderofparts)
orderofparts

library(readr)

fullstring <- ""
#reorder parts
for(i in parts[match(1:length(orderofparts), orderofparts)]){
  print(i)
  currentpart <- readr::read_file(i)
  fullstring <- paste0(fullstring, currentpart)
}

writeLines(fullstring, paste0("../salinas/compiled_resolutions/",projectname, "_resolvedcompilation.txt"))
