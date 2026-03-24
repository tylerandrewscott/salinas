# Run from the project root directory
# Usage: Rscript code/run_pipeline.R

source("code/part1_preprocessing/step1_getEISnumbers.R")
source("code/part1_preprocessing/step2_getpdffiles.R")
source("code/part1_preprocessing/step3_final_dataset_filtering.R")
source("code/part1_preprocessing/step4_file_to_text.R")
source("code/part1_preprocessing/step5_text_filter_text.r")
source("code/part1_preprocessing/step6_count_pages.r")
source("code/part2_networkgeneration/step7_spacyparse_and_networkextract.R")
source("code/part2_networkgeneration/step8_network_cleaning.R")
source("code/part2_networkgeneration/step9_make_network_object.R")
source("code/part2_networkgeneration/step10_filter_networks.R")

message("\n========== Pipeline complete ==========\n")
