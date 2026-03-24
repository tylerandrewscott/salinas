# Set to TRUE to run the page count QA check (step 6)
# This is purely diagnostic and has no effect on downstream results
if (!exists("RUN_PAGE_COUNT_CHECK")) RUN_PAGE_COUNT_CHECK <- FALSE

# Set to TRUE to force overwrite all outputs across all steps
# When FALSE, each step uses its own CLOBBER/overwrite setting
if (!exists("OVERWRITE_ALL")) OVERWRITE_ALL <- TRUE
