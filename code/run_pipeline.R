# Run from the project root directory
# Usage: Rscript code/run_pipeline.R
#
# Steps 1-3 are shared (run once), then steps 4-10 run
# for whichever flow(s) are enabled below.

# --- Choose which flows to run ---
RUN_WITHOUT_APPENDICES <- FALSE
RUN_WITH_APPENDICES    <- TRUE

# ===========================
# SHARED STEPS (run once)
# ===========================
# Step 1: Get EIS numbers
source("code/part1_preprocessing/step1_getEISnumbers.R")

# Step 2: Get PDF files (copies to pdfs_before_appendix_removal)
source("code/part1_preprocessing/step2_getpdffiles.R")

# Step 3: Final dataset filtering (produces shared eis_info_V2.csv)
# Run with INCLUDE_APPENDICES=FALSE so the done/ directory cleanup happens
INCLUDE_APPENDICES <- FALSE
app_suffix <- ""
source("code/part1_preprocessing/step3_final_dataset_filtering.R")

# ===========================
# PER-FLOW STEPS (4-10)
# ===========================
run_flow <- function() {
  source("code/part1_preprocessing/step4_file_to_text.R", local = FALSE)
  source("code/part1_preprocessing/step5_text_filter_text.r", local = FALSE)
  source("code/part1_preprocessing/step6_count_pages.r", local = FALSE)
  source("code/part2_networkgeneration/step7_spacyparse_and_networkextract.R", local = FALSE)
  source("code/part2_networkgeneration/step8_network_cleaning.R", local = FALSE)
  source("code/part2_networkgeneration/step9_make_network_object.R", local = FALSE)
  source("code/part2_networkgeneration/step10_filter_networks.R", local = FALSE)
}

if (RUN_WITHOUT_APPENDICES) {
  message("\n========== Running WITHOUT appendices ==========\n")
  INCLUDE_APPENDICES <- FALSE
  app_suffix <- ""
  run_flow()
}

if (RUN_WITH_APPENDICES) {
  message("\n========== Running WITH appendices ==========\n")
  INCLUDE_APPENDICES <- TRUE
  app_suffix <- "_withapp"
  run_flow()
}

message("\n========== Pipeline complete ==========\n")
