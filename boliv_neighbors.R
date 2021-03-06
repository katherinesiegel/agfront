### Script to get neighboring pixel info for Bolivia

### Load libraries
library(tidyverse)
library(raster)
library(furrr) # For parallelization.

# Set up parallel with furrr.
options(mc.cores = 8) # There are eight cores on a slurm node.
plan(multicore) # Specify that the job will be run in parallel across multiple cores.

### Open data
boliv <- raster("/nfs/agfrontiers-data/Remote Sensing/KS files/classi_bol_dry_2008_102033.tif")

# get values for every cell in the raster
b_values <- getValues(boliv)

### Function to calculate % neighbors of different types
percent_different_neighbors <- function(cell, r, r_values) {
  # pull neighboring values
  # see ?adjacent for the arguments used here
  x <- r_values[adjacent(r, 
                cells = cell, 
                directions = 8, 
                pairs = F, 
                include = T)]
  # calculate the percent of them that are not equal to the focal cell (i.e., not equal to the first value of x)
  perc_diff <- sum(x!=x[1])/(length(x)-1)*100
  return(perc_diff)
}

### Run on sample matrix: apply function to each cell
# map_dbl is replaced with its parallel version future_map_dbl.
perc_diff_values <- future_map_dbl(1:ncell(boliv),
                                   ~percent_different_neighbors(., r = boliv, r_values = b_values))

### Make a new raster with the cells
perc_diff_raster <- boliv %>% setValues(perc_diff_values)

writeRaster(perc_diff_raster, 
            filename = "/nfs/agfrontiers-data/Remote Sensing/KS files/bol_perc_diff.tiff",
            format = "GTiff",
            overwrite = TRUE)
