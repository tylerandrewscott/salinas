# Sys.setenv(RETICULATE_PYTHON="/Users/elisemiller/miniconda3/bin/python")
# reticulate::py_config()
# reticulate::repl_python()
import os
import numpy as np

# Function to collect files from a directory
def collect_files(directory):
    collected_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            collected_files.append(file_path)
    return collected_files

directory_to_search = "/Users/elisemiller/R_Projects/salinas/text_as_datatable"
all_files = collect_files(directory_to_search)

# Function to check for substrings in a string
def check_for_substrings(string, substrings):
    return any(substring in string for substring in substrings)

# Import substrings to check
with open('salinasbox/intermediate_data/solarwind_EISnumbers.txt', encoding="utf-8") as f:
    substrings_to_check = [line.strip() for line in f]

bool_match = np.array([check_for_substrings(file, substrings_to_check) for file in all_files])

# Filter matched files
matched_projects = np.array(all_files)[bool_match]

np.savetxt("salinasbox/intermediate_data/matched_pdf_list.tsv", matched_projects, delimiter = "\t", fmt='%s')
```
