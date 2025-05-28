# global.R - Configuraciones generales y generación de datos simulados

library(tidyverse)
library(leaflet)
library(sf)
library(jsonlite)
library(googleway)
library(shinyjs)

# ====== TOKEN DE GOOGLE (solo para funciones internas, no visible al usuario) ======
token_google <- "3169f103-2c0b-4882-b817-d26a276b16c6"  # ← reemplaza con tu token real

# ====== FUNCIONES AUXILIARES ======

# Simular función inegi_denue

source('utils/inegi_denue.R')
#inegi_denue <- function(lat, lng, palabra_clave, radio_m) {
#  # Generar 10 negocios simulados aleatorios
#  tibble(
#    nombre = paste(palabra_clave, 1:10),
#    lat = jitter(rep(lat, 10), amount = 0.01),
#    lng = jitter(rep(lng, 10), amount = 0.01),
#    categoria = palabra_clave,
#    rating = runif(10, 3, 5)
#  )
#}

# Simular objeto 'agebs' con variables socioeconómicas
#agebs <- st_as_sf(
#  tibble(
#    cvegeo = paste0("AG", 1:100),
#    poblacion = sample(100:1000, 100, replace = TRUE),
#    ingreso = runif(100, 2000, 10000),
#    escolaridad = runif(100, 0, 1),
#    lat = runif(100, 17.03, 17.13),
#    lng = runif(100, -96.77, -96.67)
#  ),
#  coords = c("lng", "lat"),
#  crs = 4326
#)

# Crear hexágonos ficticios para mapa
#library(geogrid)
#
#hex_grid <- calculate_grid(agebs_oax, grid_type = "hexagon", seed = 1)
#agebs_hex <- assign_polygons(agebs_oax, hex_grid)
#agebs_hex$poblacion <- agebs$poblacion
#plot(hex_grid)

# ====== CARGA DE DATOS REALES (comentada) ======
 agebs <- st_read("data/Oaxaca_grid/oaxaca_ZMO_grid.shp", quiet = TRUE)
# negocios <- read_csv("datos/denue.csv")
# clientes <- read_csv("datos/clientes.csv")
# ratings <- read_csv("datos/ratings.csv")
 agebs <- agebs %>% 
   mutate(poblacion = poblacn,
          escolaridad = esclrdd)
   
 agebs_hex <- agebs

