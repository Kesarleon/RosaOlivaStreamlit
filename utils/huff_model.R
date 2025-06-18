# Función para calcular captación con el modelo de Huff (datos simulados)
# Para usar Google Places, descomenta la siguiente línea:
source('utils/google_places.R')

# models/modelo_huff.R
# Modelo de Huff para estimar captación
# Datos simulados

modelo_huff <- function(sucursales, clientes, alfa = 1, beta = 2) {
  # sucursales: data.frame con lat, lon, id, atractivo
  # clientes: data.frame con lat, lon, id, poblacion
  
  calc_dist <- function(x1, y1, x2, y2) {
    sqrt((x1 - x2)^2 + (y1 - y2)^2)
  }
  
  resultado <- clientes %>%
    rowwise() %>%
    mutate(
      probas = list({
        distancias <- sapply(1:nrow(sucursales), function(i) {
          calc_dist(long, lat, sucursales$long[i], sucursales$lat[i])
        })
        atractivos <- sucursales$atractivo
        scores <- (atractivos^alfa) / (distancias^beta + 1e-6)
        captacion <- scores / sum(scores)
        tibble(id_sucursal = sucursales$id, captacion = captacion)
      })
    ) %>%
    unnest(probas)
  
  return(resultado)
}
