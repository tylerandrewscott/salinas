
raw_num_empties <- sapply(raw_text_files, function(file) {
  dt <- fread(file)
  
  str_extract_all(string = dt, pattern = "(\\u2022)+")
  
  #less common bullets
  #bullets <- c(204c, 204d, 2022, 
    #2219 bullet operator in math
    #2619, 25c9, 2023, 25e6, 2043, 2024, 25cc)
  
})