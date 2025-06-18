# global.R - Configuraciones generales y generación de datos simulados

library(tidyverse)
library(leaflet)
library(sf)
library(jsonlite)
library(googleway)
library(shinyjs)
library(DT)
library(geosphere)

# ====== TOKEN DE GOOGLE (solo para funciones internas, no visible al usuario) ======
token_google <- Sys.getenv("GOOGLE_PLACES_API_KEY")  # ← Corregido: agregadas comillas
token_inegi <- Sys.getenv("INEGI_API_KEY")
# ====== FUNCIONES AUXILIARES ======

# Cargar función inegi_denue
source('utils/inegi_denue.R')

# ====== CARGA DE DATOS REALES ======
# Verificar si existe el archivo antes de cargarlo
if (file.exists("data/Oaxaca_grid/oaxaca_ZMO_grid.shp")) {
  agebs <- st_read("data/Oaxaca_grid/oaxaca_ZMO_grid.shp", quiet = TRUE)
  
  # Estandarizar nombres de columnas
  agebs <- agebs %>% 
    mutate(
      id_hex = id_hx_x,
      poblacion_total = pblcn_t,
      joven_digital = log1p(jvn_dgt),
      mama_emprendedora = log1p(mm_mprn),
      mayorista_experimentado = log1p(myrst_x),
      clientes_totales = log1p(cts_ttl),
    ) %>%
    select(id_hex, poblacion_total, joven_digital, mama_emprendedora, mayorista_experimentado, clientes_totales, geometry)
  
  agebs_hex <- agebs
  
} else {
  # Crear datos simulados si no existe el archivo
  warning("No se encontró el archivo de datos. Usando datos simulados.")
  
  # Crear hexágonos simulados
  n_hex <- 50
  hex_coords <- data.frame(
    lng = runif(n_hex, -96.75, -96.69),
    lat = runif(n_hex, 17.04, 17.11)
  )
  
  # Crear polígonos hexagonales simples (círculos para simplicidad)
  hex_polys <- lapply(1:n_hex, function(i) {
    center <- c(hex_coords$lng[i], hex_coords$lat[i])
    angles <- seq(0, 2*pi, length.out = 7)
    radius <- 0.002
    coords <- cbind(
      center[1] + radius * cos(angles),
      center[2] + radius * sin(angles)
    )
    st_polygon(list(coords))
  })
  
  agebs_hex <- st_sf(
    id_hex = 1:n_hex,
    poblacion = sample(100:1000, n_hex, replace = TRUE),
    escolaridad = runif(n_hex, 6, 12),
    ingreso = runif(n_hex, 5000, 15000),
    geometry = st_sfc(hex_polys, crs = 4326)
  )
  
  agebs <- agebs_hex
}

agebs <- st_read("data/Oaxaca_grid/oaxaca_ZMO_grid.shp", quiet = TRUE)
agebs %>% class()
