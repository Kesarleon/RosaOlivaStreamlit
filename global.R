#' @file global.R
#' @description
#' This script manages global configurations, loads necessary libraries,
#' defines API keys (intended to be loaded from environment variables),
#' sources utility functions, and handles the initial loading and processing
#' of core datasets (e.g., `agebs_hex`). It ensures that data and common
#' resources are available throughout the Shiny application.
#' If specific datasets are not found, it falls back to generating simulated data
#' to allow the application to run for demonstration or development purposes.


# --- Core Libraries ---
library(tidyverse) # Collection of R packages for data science (dplyr, ggplot2, etc.)
library(leaflet)   # Interactive web maps
library(sf)        # Simple Features for R, for spatial data
library(jsonlite)  # JSON parsing
library(googleway) # Google Maps API client
library(shinyjs)   # Extend Shiny with JavaScript actions
library(DT)        # Interactive DataTables
library(geosphere) # Spherical trigonometry for geographic distances
library(Hmisc)

# --- Application Configuration ---
APP_CONFIG <- list(
  default_lat = 17.0594,
  default_lng = -96.7216,
  oaxaca_grid_filepath = "data/Oaxaca_grid/oaxaca_ZMO_grid.shp",
  huff_default_alfa = 1,
  huff_default_beta = 3,
  map_search_radius_default = 1000,
  map_search_keyword_default = "joyeria",
  socio_search_keyword_default = "joyeria", # Can be different from map_search_keyword_default if needed
  sucursales_rosa_data = data.frame(
    id = c("A", "B", "C"),
    nombre = c("Sucursal Violetas", "Sucursal Poniente", "Sucursal Sur"),
    lat = c(17.078904, 17.07, 17.05),
    lng = c(-96.710641, -96.73, -96.71),
    atractivo = c(4.0, 4.0, 4.2), # Example attractiveness scores
    stringsAsFactors = FALSE
  ),
  competencia_base_data = data.frame(
    id = c("X", "Y", "Z"),
    nombre = c("Joyería Nice", "Joyería Sublime", "Joyería Ag 925"),
    lat = c(17.078891, 17.078206, 17.080318),
    lng = c(-96.710177, -96.710654, -96.713559),
    stringsAsFactors = FALSE
  )
)

# --- API Keys ---
# It is strongly recommended to set these as environment variables for security.
# Example: Sys.setenv(GOOGLE_PLACES_API_KEY = "YOUR_KEY_HERE")

# API Key for Google Services (e.g., Google Places API)
# Note: GOOGLE_PLACES_API_KEY is also directly accessed by utils/google_places.R via Sys.getenv().
# This global variable 'token_google' is available for other potential uses within the app if needed.
token_google <- Sys.getenv("GOOGLE_PLACES_API_KEY")

# API Key for INEGI services (e.g., DENUE API)
token_inegi <- Sys.getenv("INEGI_API_KEY")

# --- Utility Functions ---
# Load custom utility functions. Ensure paths are correct.
source("utils/inegi_denue.R") # Function to interact with INEGI DENUE API

# --- Data Loading: Hexagonal Grid Data (AGEBs) ---
# This section loads the primary hexagonal grid data (`agebs_hex`).
# It first attempts to load real data from a shapefile using path from APP_CONFIG.
# If the real data is not found, it generates simulated data with a similar structure.

if (file.exists(APP_CONFIG$oaxaca_grid_filepath)) {
  # Load real data if available
  agebs_hex <- st_read(APP_CONFIG$oaxaca_grid_filepath, quiet = TRUE)
  
  # Check if NOM_MUN and NOM_LOC exist, if not, create placeholder columns
  if (!"NOM_MUN" %in% names(agebs_hex)) {
    warning("Column 'NOM_MUN' not found in shapefile. Adding placeholder 'Desconocido'.")
    agebs_hex$NOM_MUN <- "Desconocido"
  }
  if (!"NOM_LOC" %in% names(agebs_hex)) {
    warning("Column 'NOM_LOC' not found in shapefile. Adding placeholder 'Desconocida'.")
    agebs_hex$NOM_LOC <- "Desconocida"
  }

  # Standardize column names and apply transformations
  agebs_hex <- agebs_hex %>%
    mutate(
      id_hex = id_hx_x,
      poblacion_total = pblcn_t,
      joven_digital = log1p(jvn_dgt),
      mama_emprendedora = log1p(mm_mprn),
      mayorista_experimentado = log1p(myrst_x),
      clientes_totales = log1p(cts_ttl),
      nombre_municipio = as.character(NOM_MUN), # Add municipio name
      nombre_localidad = as.character(NOM_LOC)  # Add localidad name
    ) %>%
    select(
      id_hex, poblacion_total, joven_digital, mama_emprendedora,
      mayorista_experimentado, clientes_totales,
      nombre_municipio, nombre_localidad, # Keep the new columns
      geometry
    )
  
  message("Successfully loaded real hexagonal grid data from: ", APP_CONFIG$oaxaca_grid_filepath)
  
  # Add a message to confirm if columns were added or placeholders were used
  if ("nombre_municipio" %in% names(agebs_hex) && any(agebs_hex$nombre_municipio == "Desconocido" & !"NOM_MUN" %in% names(st_read(APP_CONFIG$oaxaca_grid_filepath, quiet = TRUE)))) {
      message("Placeholder values used for 'nombre_municipio' as 'NOM_MUN' was not found in the original shapefile.")
  } else if ("nombre_municipio" %in% names(agebs_hex)) {
      message("Successfully added 'nombre_municipio' from 'NOM_MUN' (or it already existed and was processed).")
  }

  if ("nombre_localidad" %in% names(agebs_hex) && any(agebs_hex$nombre_localidad == "Desconocida" & !"NOM_LOC" %in% names(st_read(APP_CONFIG$oaxaca_grid_filepath, quiet = TRUE)))) {
      message("Placeholder values used for 'nombre_localidad' as 'NOM_LOC' was not found in the original shapefile.")
  } else if ("nombre_localidad" %in% names(agebs_hex)) {
      message("Successfully added 'nombre_localidad' from 'NOM_LOC' (or it already existed and was processed).")
  }

} else {
  # Generate simulated data if real data file is not found
  warning(
    paste0(
      "REAL DATA NOT FOUND: '", APP_CONFIG$oaxaca_grid_filepath, "' was not found. ",
      "Using SIMULATED hexagonal grid data instead. Features and accuracy will be limited."
    ),
    call. = FALSE
  )
  
  n_hex <- 50 # Number of simulated hexagons
  hex_coords <- data.frame(
    lng = runif(n_hex, -96.75, -96.69),
    lat = runif(n_hex, 17.04, 17.11)
  )
  
  hex_polys <- lapply(1:n_hex, function(i) {
    center <- c(hex_coords$lng[i], hex_coords$lat[i])
    angles <- seq(0, 2 * pi, length.out = 7)
    radius <- 0.002
    coords <- cbind(
      center[1] + radius * cos(angles),
      center[2] + radius * sin(angles)
    )
    st_polygon(list(coords))
  })
  
  agebs_hex <- st_sf(
    id_hex = paste0("sim_hex_", 1:n_hex),
    poblacion_total = sample(100:1000, n_hex, replace = TRUE),
    joven_digital = log1p(sample(0:500, n_hex, replace = TRUE)),
    mama_emprendedora = log1p(sample(0:500, n_hex, replace = TRUE)),
    mayorista_experimentado = log1p(sample(0:500, n_hex, replace = TRUE)),
    clientes_totales = log1p(sample(0:2000, n_hex, replace = TRUE)),
    geometry = st_sfc(hex_polys, crs = 4326)
  ) %>%
    select(
      id_hex, poblacion_total, joven_digital, mama_emprendedora,
      mayorista_experimentado, clientes_totales, geometry
    )
  
  message("Generated simulated hexagonal grid data.")
}

# --- Data Compatibility ---
agebs <- agebs_hex

# --- Optional Debugging Checks ---
# message("Class of 'agebs_hex': ", class(agebs_hex)[1])
# print(head(agebs_hex))

message("Global script execution finished.")
# Any other global configurations or objects can be defined below.
