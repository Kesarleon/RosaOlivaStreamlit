# -----------------------------------------------------------------------------
# Script: utils/perfiles.R
#
# Purpose:
#   To perform Principal Component Analysis (PCA) on selected variables from
#   the Oaxaca census data (CPV 2020) to generate customer profile indices.
#   These indices are then used to estimate the number of potential customers
#   for different profiles within each AGEB.
#
# Inputs:
#   - Oaxaca census data: `../data/CensoOaxaca/conjunto_de_datos/conjunto_de_datos_ageb_urbana_20_cpv2020.csv`
#     (AGEB Urbana level data from Censo de Población y Vivienda 2020).
#
# Output:
#   - RDS file: `data/perfiles.rds`
#     This file contains a data frame with AGEB identifiers (CVEGEO) and the
#     calculated profile indices and estimated customer counts per profile.
#
# Note:
#   This script is intended for manual execution as part of the data preparation
#   process. It should not be run directly by the Shiny application.
#   Ensure the input CSV file path is correct relative to your project structure.
# -----------------------------------------------------------------------------

# --- 1. Load Libraries ---
library(tidyverse)  # For data manipulation (dplyr, tidyr, etc.) and ggplot2
library(FactoMineR) # For Principal Component Analysis (PCA)
library(factoextra) # For visualizing PCA results (e.g., fviz_contrib)
library(tibble)     # For tibble data structures
library(scales)     # For rescaling data (e.g., rescale function)

# Optional libraries for further EDA (commented out if not strictly needed for output)
# library(ggplot2)  # Already part of tidyverse
# library(ggExtra)  # For marginal histograms with ggplot2
# library(GGally)   # For ggpairs plot matrix

# --- 2. Load and Prepare Census Data ---
# Define the path to the census data CSV file
census_file_path <- "../data/CensoOaxaca/conjunto_de_datos/conjunto_de_datos_ageb_urbana_20_cpv2020.csv"

# Check if file exists
if (!file.exists(census_file_path)) {
  stop("Census data file not found at: ", census_file_path,
       "\nPlease ensure the path is correct and the file is available.")
}

oaxaca_censo <- read.csv(census_file_path, stringsAsFactors = FALSE) # Read CSV

# Data Cleaning and Preparation
oaxaca_censo <- oaxaca_censo %>%
  filter(grepl('^Total', NOM_LOC) == FALSE) %>% # Remove "Total Localidad" summary rows
  mutate(across(
    .cols = where(is.character), # Replace "*" (common NA indicator in census data) with proper NA
    .fns = ~ ifelse(. == "*", NA_character_, .)
  ))

# Convert relevant columns (from column 9 onwards) to numeric
# Ensure column indices are correct for your specific dataset version
oaxaca_censo <- oaxaca_censo %>%
  mutate_at(vars(9:ncol(oaxaca_censo)), as.numeric)

# Create CVEGEO identifier by concatenating state, municipality, locality, and AGEB codes
oaxaca_censo <- oaxaca_censo %>%
  mutate(CVEGEO = paste0(
    sprintf('%02d', ENTIDAD),
    sprintf('%03d', MUN),
    sprintf('%04d', LOC),
    sprintf('%04s', AGEB)
  ))

# glimpse(oaxaca_censo) # For quick inspection

# --- Define Variables for Each Customer Profile ---
# These variable names should match columns in the census data.
vars_joven <- c(
  'P_18A24',    # Population 18-24 years
  'P18A24A',    # Population 18-24 years that attends school
  'PEA',        # Economically Active Population
  'GRAPROES',   # Average schooling grade
  'TVIVPARHAB', # Total occupied private dwellings
  'VPH_PC',     # Dwellings with a computer
  'VPH_CEL',    # Dwellings with a cell phone
  'VPH_INTER',  # Dwellings with internet access
  'VPH_SINTIC'  # Dwellings without ICT (used inversely)
)

vars_mama <- c(
  'P_15A49_F',  # Female population 15-49 years
  'P_15A17_F',  # Female population 15-17 years
  'P_18A24_F',  # Female population 18-24 years
  'PROM_HNV',   # Average number of live births
  'P18YM_PB_F', # Female population 18+ with basic education
  'GRAPROES_F', # Average schooling grade for females
  'POCUPADA_F', # Occupied female population
  'TOTHOG',     # Total households
  'HOGJEF_F',   # Households with female head
  'PHOGJEF_F',  # Percentage of households with female head
  'VPH_CEL',    # Dwellings with a cell phone
  'VPH_INTER'   # Dwellings with internet access
)

vars_mayorista <- c(
  'POBTOT',     # Total population
  'POB0_14',    # Population 0-14 years
  'P_15A17',    # Population 15-17 years
  'P_18A24',    # Population 18-24 years
  'P_60YMAS',   # Population 60+ years
  "P18YM_PB",   # Population 18+ with basic education
  "VPH_AUTOM"   # Dwellings with an automobile
)

# --- 3. PCA Function for Profiles ---
hacer_pca_perfil <- function(data, variables, nombre_perfil) {
  # Select only the specified variables for PCA
  sub_data <- data %>% select(all_of(variables))

  # Handle potential NAs: PCA function might handle them, or imputation might be needed.
  # For simplicity, FactoMineR's PCA handles NAs by default (e.g. using mean imputation for calculation of PCs).
  # Check documentation if specific NA handling is required.
  if(any(!complete.cases(sub_data))){
    warning("Data for profile '", nombre_perfil, "' contains NA values. PCA will proceed with FactoMineR's default NA handling.", call. = FALSE)
  }

  # Perform PCA
  res.pca <- PCA(sub_data, scale.unit = TRUE, graph = FALSE) # Scale unit is important
  
  # Extract the first principal component as the profile index
  # The first PC usually captures the most variance.
  indice <- res.pca$ind$coord[, 1]
  
  # Create a data frame for the index to ensure proper column naming
  result_df <- data.frame(indice_col = indice)
  names(result_df) <- paste0("indice_", nombre_perfil) # Dynamic column name
  
  # Optional: Print summary and contribution plot for diagnostics
  # print(paste("PCA Eigenvalues for Profile:", nombre_perfil))
  # print(res.pca$eig[1:min(3, nrow(res.pca$eig)), ]) # Show top 3 eigenvalues
  # print(fviz_contrib(res.pca, choice = "var", axes = 1, top = length(variables)) +
  #   labs(title = paste("Variable Contributions to PC1 -", nombre_perfil)))
  
  return(list(data_con_indice = result_df, pca_results = res.pca))
}

# --- Prepare Data for PCA ---
# Select relevant columns and aggregate if necessary (e.g., if data is not at AGEB level yet)
# This script assumes oaxaca_censo is already at the AGEB level.
oaxaca_ageb_pca_input <- oaxaca_censo %>%
  select(all_of(c('CVEGEO', 'NOM_ENT', 'NOM_MUN', 'NOM_LOC', 'AGEB',
                  vars_joven, vars_mama, vars_mayorista)))

# If data needs aggregation (e.g., from manzana to AGEB), it would be done here.
# Example (if it were needed):
# oaxaca_ageb_pca_input <- oaxaca_ageb_pca_input %>%
#   group_by(CVEGEO, NOM_ENT, NOM_MUN, NOM_LOC, AGEB) %>%
#   summarise(across(all_of(c(vars_joven, vars_mama, vars_mayorista)),
#                    ~sum(., na.rm = TRUE)), # Summing variables for aggregation
#             .groups = 'drop')

# --- Perform PCA for Each Profile ---
# Joven Digital: Note VPH_SINTIC is used inversely (multiplied by -1)
# This implies that *fewer* dwellings without ICT contributes positively to the "digital" profile.
res_joven_list <- hacer_pca_perfil(
  data = oaxaca_ageb_pca_input %>% mutate(VPH_SINTIC = VPH_SINTIC * (-1)), # Invert SINTIC
  variables = vars_joven,
  nombre_perfil = "joven_digital"
)

# Mamá Emprendedora: Creating a combined variable POB_MAMA
res_mama_list <- hacer_pca_perfil(
  data = oaxaca_ageb_pca_input %>% mutate(POB_MAMA = P_15A49_F - P_15A17_F - P_18A24_F),
  variables = c('POB_MAMA', vars_mama), # Include the new variable in PCA if desired, or use original vars_mama
  nombre_perfil = "mama_emprendedora"
)

# Mayorista Experimentado: Creating a combined variable POB_MAYOR
res_mayorista_list <- hacer_pca_perfil(
  data = oaxaca_ageb_pca_input %>% mutate(POB_MAYOR = POBTOT - POB0_14 - P_15A17 - P_18A24 - P_60YMAS),
  variables = c('POB_MAYOR', vars_mayorista), # Include the new variable
  nombre_perfil = "mayorista_experimentado"
)

# --- Combine Profile Indices with AGEB Data ---
agebs_perfiles <- oaxaca_ageb_pca_input %>%
  bind_cols(res_joven_list$data_con_indice) %>%
  bind_cols(res_mama_list$data_con_indice) %>%
  bind_cols(res_mayorista_list$data_con_indice)

# --- Estimate Potential Customers ---
# Rescale indices to a 0-1 range (afinidad) to represent affinity/propensity.
# Then multiply by relevant population segments and arbitrary factors (0.60, 0.30, 0.10).
# These factors represent assumed market penetration or relevance of the profile.
agebs_potencial <- agebs_perfiles %>%
  mutate(
    afinidad_joven = scales::rescale(indice_joven_digital, to = c(0, 1)),
    afinidad_mama = scales::rescale(indice_mama_emprendedora, to = c(0, 1)),
    afinidad_mayorista = scales::rescale(indice_mayorista_experimentado, to = c(0, 1)),

    # Estimated customers for each profile
    estimado_ctes_joven = round((P18A24A) * afinidad_joven * 0.60), # 60% of relevant pop * affinity
    estimado_ctes_mama = round((P_15A49_F - P_15A17_F - P_18A24_F) * afinidad_mama * 0.30), # 30%
    estimado_ctes_mayorista = round((P18YM_PB) * afinidad_mayorista * 0.10), # 10%

    # Total estimated customers, capped at 30% of total AGEB population (POBTOT)
    # This cap is an arbitrary business rule.
    estimado_ctes_total = round(pmin(
      (estimado_ctes_joven + estimado_ctes_mama + estimado_ctes_mayorista),
      POBTOT * 0.30 # Cap at 30% of total population
    ))
  )

# --- Summary and EDA (Optional) ---
# Summary of estimated customers and percentages
# agebs_potencial %>%
#   select(POBTOT, starts_with('estimado')) %>%
#   mutate(
#     porc_joven = estimado_ctes_joven / POBTOT,
#     porc_mama = estimado_ctes_mama / POBTOT,
#     porc_mayorista = estimado_ctes_mayorista / POBTOT
#   ) %>%
#   summary()

# Histograms of estimated customers (requires ggplot2, part of tidyverse)
# ggplot(agebs_potencial, aes(x = estimado_ctes_joven)) + geom_histogram(bins = 30)
# ggplot(agebs_potencial, aes(x = estimado_ctes_mama)) + geom_histogram(bins = 30)
# ggplot(agebs_potencial, aes(x = estimado_ctes_mayorista)) + geom_histogram(bins = 30)
# ggplot(agebs_potencial, aes(x = estimado_ctes_total)) + geom_histogram(bins = 30)

# glimpse(agebs_potencial)

# --- Prepare Final Data for Saving ---
# Select relevant columns for the final output
agebs_potencial_final <- agebs_potencial %>%
  select(
    CVEGEO, POBTOT, # Key identifiers and total population
    starts_with("estimado_ctes_") # All estimated customer columns
  ) %>%
  # Adding a small constant to avoid zeros if log transformation is applied later (as in original script)
  # This step might need review based on how data is used downstream.
  mutate(
    estimado_ctes_joven = estimado_ctes_joven + 5,
    estimado_ctes_mama = estimado_ctes_mama + 5,
    estimado_ctes_mayorista = estimado_ctes_mayorista + 5,
    estimado_ctes_total = estimado_ctes_total + 5
  )

# glimpse(agebs_potencial_final)

# --- Save Output ---
# Ensure the 'data' directory exists
if (!dir.exists("data")) {
  dir.create("data", recursive = TRUE)
}
saveRDS(agebs_potencial_final, file = 'data/perfiles.rds')
message("Successfully generated and saved customer profile data to data/perfiles.rds")

# --- Further EDA (Commented Out - For manual execution if needed) ---
# These were at the end of the original script.
# Package installation should be done manually in the console, not in scripts.

# # For ggExtra:
# # install.packages("ggExtra") # Run in console if not installed
# library(ggExtra)
# p <- ggplot(agebs_potencial, aes(x = POBTOT, y = estimado_ctes_joven)) +
#   geom_point(color = "steelblue", size = 2) +
#   theme_minimal()
# ggMarginal(p, type = "histogram", fill = "gray", color = "black")

# # For GGally:
# # devtools::install_github("ggobi/ggally") # Run in console if not installed
# library(GGally)
# agebs_potencial_final %>%
#   select(POBTOT, starts_with('estimado_ctes_')) %>%
#   ggpairs()

# # Log-transformed histograms (example)
# pob_data_check <- readRDS('data/perfiles.rds')
# ggplot(pob_data_check, aes(x = log1p(estimado_ctes_joven))) + geom_histogram(bins=30) # log1p = log(x+1)
# summary(pob_data_check)
