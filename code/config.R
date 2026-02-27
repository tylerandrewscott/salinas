# Set to TRUE to use original PDFs (with appendices)
# Set to FALSE to use appendix-removed PDFs
# When sourced from run_pipeline.R, these are already set — only apply defaults
if (!exists("INCLUDE_APPENDICES")) INCLUDE_APPENDICES <- TRUE

# Set to TRUE to run the page count QA check (step 6)
# This is purely diagnostic and has no effect on downstream results
if (!exists("RUN_PAGE_COUNT_CHECK")) RUN_PAGE_COUNT_CHECK <- FALSE

# Set to TRUE to force overwrite all outputs across all steps
# When FALSE, each step uses its own CLOBBER/overwrite setting
if (!exists("OVERWRITE_ALL")) OVERWRITE_ALL <- TRUE

# Derived suffix used by all scripts to separate outputs
app_suffix <- if (INCLUDE_APPENDICES) "_withapp" else ""
