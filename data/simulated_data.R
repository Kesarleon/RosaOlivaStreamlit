# Aquí se generan los datos simulados (AGEBs, ratings, showrooms, etc.)
# Para usar datos reales, descomenta la siguiente línea:
# load('data/real_data.RData')

# utils/simulacion_datos.R
# Datos simulados para agebs, clientes y sucursales

simular_datos <- function() {
  agebs <- data.frame(
    id = paste0("AGEB_", 1:100),
    lat = runif(100, 17.02, 17.14),
    lon = runif(100, -96.75, -96.6),
    ingreso = rnorm(100, 8000, 1500),
    educacion = runif(100, 0.5, 1),
    hogares = sample(100:1000, 100),
    poblacion = sample(200:2000, 100)
  )
  
  clientes <- agebs %>%
    sample_n(50) %>%
    mutate(id = paste0("CL_", row_number()))
  
  sucursales <- data.frame(
    id = paste0("RO_", 1:3),
    lat = c(17.07, 17.1, 17.05),
    long = c(-96.72, -96.68, -96.7),
    atractivo = c(4.5, 3.8, 4.0)
  )
  
  list(agebs = agebs, clientes = clientes, sucursales = sucursales)
}
