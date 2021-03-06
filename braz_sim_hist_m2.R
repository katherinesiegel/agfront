### Simulation histogram
# Modified by QDR 9 June 2021

# Load packages
library(raster)
library(sf)
library(dplyr)
library(readr)

### Open brazil 2008 map
bra_2008 <- raster("/nfs/agfrontiers-data/Remote Sensing/KS files/classi_bra_dry_2008_102033.tif")

### Open brazil 2018 map
bra_2018 <- raster("/nfs/agfrontiers-data/Remote Sensing/KS files/classi_bra_dry_2018_102033.tif")

### Open buffer
jaman <- st_read("/nfs/agfrontiers-data/Case Study Info/Brazil/JamanBuffer/JamanBuffer.shp") %>%
  st_transform(., crs = "+proj=aea +lat_0=-32 +lon_0=-60 +lat_1=-5 +lat_2=-42 +x_0=0 +y_0=0
+ellps=aust_SA +units=m +no_defs")

### Crop LUC maps
jaman_08 <- crop(bra_2008, jaman)
jaman_08 <- mask(jaman_08, jaman, filename = '/nfs/agfrontiers-data/Remote Sensing/KS files/jaman_08_mask.tif',
                 overwrite = TRUE)
jaman_18 <- crop(bra_2018, jaman)
jaman_18 <- mask(jaman_18, jaman, filename = '/nfs/agfrontiers-data/Remote Sensing/KS files/jaman_18_mask.tif',
                 overwrite = TRUE)

### Reclassification matrix
reclass_df <- c(0, 1.5, 0.05,       ## ag
                1.6, 2.2, 0.1,      ## forest
                2.6, 3.2, 0.15,     ## bare soil
                3.6, 4.2, 0.2,      ## urban
                4.6, 5.2, 0.25,     ## wetland
                5.6, 7.2, 0.3)      ## water
reclass_m <- matrix(reclass_df,
                    ncol = 3,
                    byrow = TRUE)

### Reclassify 2018
bra_18_rc <- reclassify(jaman_18,
                        reclass_m)

### Reclassification for subtracted rasters
reclass_sub_df <- c(-0.06, -0.04, 1,  ## missed conversion to ag
                    -0.11, -0.09, 2,    ## correct forest
                    -0.4, -0.14, 0,    ## other
                    0.89, 0.91, 3,    ## incorrectly predicted ag conversion
                    0.6, 0.86, 0,    ## other
                    0.94, 0.96, 4)   ## correctly predicted ag conversion
reclass_sub_m <- matrix(reclass_sub_df,
                        ncol = 3,
                        byrow = TRUE)

### Rasters for model 2
m2_layers <- list.files(path = "/nfs/agfrontiers-data/luc_model/brazil_2_project_2018",
                        pattern = "*.tif",
                        full.names = TRUE)

### Data frame of results
results <- list()

### Write loop
for (i in 1:length(m2_layers)) {
  
  ### Open first raster
  j_m2 <- raster(m2_layers[i])
  
  ### Restrict to extent of national forest
  j_m2 <- crop(j_m2, jaman)
  j_m2 <- mask(j_m2, jaman)
  
  
  ### Mask cells that were ag in 2008
  j2_mask_08 <- mask(j_m2, 
                     jaman_08,
                     inverse = FALSE,
                     maskvalue = 1,
                     updatevalue = 8)
  
  ### Subtract rasters
  j2_mask_08_sub <- j2_mask_08 - bra_18_rc
  
  ### Reclassify subtracted raster
  j2_mask_08_sub_rc <- reclassify(j2_mask_08_sub,
                                  reclass_sub_m)
  
  j2_freq <- freq(j2_mask_08_sub_rc)
  
  results[[i]] <- j2_freq
  
  removeTmpFiles() # Clean up temp files, if any exist.
  
}

### Combine into dataframe. Add a column for which of the 1000 rasters it comes from.
results_df <- bind_rows(lapply(results, as_tibble), .id = "raster_id")

### Save dataframe
write_csv(results_df,
          "/nfs/agfrontiers-data/luc_model/brazil_2_project_2018_freq.csv")

