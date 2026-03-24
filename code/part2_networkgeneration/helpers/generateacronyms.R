library(data.table)
library(stringr)
library(jsonlite)
library(parallel)
myfiles <- list.files("salinasbox/clean_data/pdf_to_text_clean")

eis_nums <- unique(substr(myfiles, 1, 8))
mytexts <- vector(mode = "list", length = length(eis_nums))

names(mytexts) <- eis_nums
#squish individual rds files into full project text
filenum = 1
for(i in 1:length(mytexts)){
  mytexts[[i]] <- readRDS(paste0(
    "salinasbox/clean_data/pdf_to_text_clean/", myfiles[filenum]))$text
  filenum = filenum + 1
  while(filenum <= length(myfiles) & substr(myfiles[filenum], 1, 8) == eis_nums[i]){
    mytexts[[i]] <- append(mytexts[[i]],
                           readRDS(paste0(
                             "salinasbox/clean_data/pdf_to_text_clean/",
                             myfiles[filenum]))$text)
    filenum = filenum + 1
  }
}

# Source 1: per-project acronyms from LLM-extracted glossary/acronym sections.
# Each cache file is named {eis}_{rest}.json and was produced by
# extract_acronym_glossaries.py. All files under the same EIS number are
# assumed to use the same acronym definitions; first occurrence wins.
cache_dir <- "salinasbox/intermediate_data/dictionaries/acronym_glossaries_cache"
cache_files <- list.files(cache_dir, pattern = "\\.json$", full.names = TRUE)
cache_by_eis <- split(cache_files, substr(basename(cache_files), 1, 8))

cache_acr <- vector(mode = "list", length = length(eis_nums))
names(cache_acr) <- eis_nums

for(eis in eis_nums){
  matching <- cache_by_eis[[eis]]
  if(length(matching) == 0){
    cache_acr[[eis]] <- data.frame(acronym = character(0), name = character(0),
                                   stringsAsFactors = FALSE)
    next
  }
  entries_list <- lapply(matching, function(f){
    entries <- tryCatch(jsonlite::fromJSON(f, simplifyDataFrame = TRUE),
                        error = function(e) NULL)
    if(is.null(entries) || length(entries) == 0 || !is.data.frame(entries)) return(NULL)
    if(nrow(entries) == 0) return(NULL)
    entries <- entries[entries$type == "acronym" &
                         nchar(trimws(entries$term)) > 1 &
                         nchar(trimws(entries$expansion)) > 0 &
                         !grepl(";", entries$term, fixed = TRUE), ]
    if(nrow(entries) == 0) return(NULL)
    # normalize terms: strip embedded periods (U.S. -> US) and
    # trailing parenthetical suffixes (dB(A) -> dB)
    terms <- trimws(entries$term)
    terms <- gsub("\\([^)]*\\)$", "", terms)  # strip trailing parentheticals
    terms <- gsub("\\.", "", terms)            # strip periods
    terms <- trimws(terms)
    data.frame(acronym = terms,
               name    = trimws(entries$expansion),
               stringsAsFactors = FALSE)
  })
  all_entries <- do.call(rbind, Filter(Negate(is.null), entries_list))
  if(is.null(all_entries) || nrow(all_entries) == 0){
    cache_acr[[eis]] <- data.frame(acronym = character(0), name = character(0),
                                   stringsAsFactors = FALSE)
    next
  }
  cache_acr[[eis]] <- all_entries[!duplicated(all_entries$acronym), ]
}

# Source 2: find_acronyms detects parenthetically-defined acronyms in text
# (e.g. "Bureau of Land Management (BLM)"). These supplement the cache
# entries without overwriting them.
find_acr <- mclapply(mytexts, find_acronyms, mc.cores = detectCores() - 1)
names(find_acr) <- eis_nums

# Combine: cache is primary, find_acronyms supplements
myacronyms <- vector(mode = "list", length = length(eis_nums))
names(myacronyms) <- eis_nums
for(i in 1:length(eis_nums)){
  eis <- eis_nums[i]
  combined <- rbind(cache_acr[[eis]], find_acr[[eis]])
  myacronyms[[i]] <- combined[!duplicated(combined$acronym), ]
}

saveRDS(myacronyms, "salinasbox/intermediate_data/project_specific_acronyms.RDS")
