source("code/config.R")
library(tidyverse)

timeline <- read_csv("salinasbox/raw_data/CEQ_EIS_Timeline_Data.csv")
projdeets <- readRDS("salinasbox/solarwind_project_details_V2.RDS")

