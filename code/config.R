# Set to TRUE to use original PDFs (with appendices)
# Set to FALSE to use appendix-removed PDFs
INCLUDE_APPENDICES <- TRUE

# Set to TRUE to run the page count QA check (step 6)
# This is purely diagnostic and has no effect on downstream results
RUN_PAGE_COUNT_CHECK <- FALSE

# Derived suffix used by all scripts to separate outputs
app_suffix <- if (INCLUDE_APPENDICES) "_withapp" else ""
