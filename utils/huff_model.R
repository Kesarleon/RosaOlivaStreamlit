# Función para calcular captación con el modelo de Huff (datos simulados)
# Para usar Google Places, descomenta la siguiente línea:
source('utils/google_places.R')

#library(dplyr) # May not be strictly needed for the new function structure
library(geosphere)

huff_model <- function(ag_lat, ag_lng, puntos, alfa = 1, beta = 2) {
  # puntos: data.frame con lat, lng, id, atractivo
  # ag_lat, ag_lng: latitude and longitude of the current demand point (e.g., AGEB)
  # alfa: attraction parameter
  # beta: distance friction parameter
  
  tryCatch({
    # Calculate distances using geosphere for mayor precision
    puntos$distancia <- geosphere::distHaversine(
      cbind(puntos$lng, puntos$lat),
      c(ag_lng, ag_lat)
    ) / 1000  # Convertir a km
    
    # Evitar división por cero
    puntos$distancia[puntos$distancia == 0] <- 0.01 # small distance if same point
    
    # Calcular utilidad con parámetros alfa y beta
    puntos$utilidad <- (puntos$atractivo ^ alfa) / (puntos$distancia ^ beta)
    
    # Calcular probabilidades
    total_utilidad <- sum(puntos$utilidad, na.rm = TRUE)
    if (total_utilidad > 0) {
      puntos$prob <- puntos$utilidad / total_utilidad
    } else {
      # If total_utilidad is 0 (e.g. all attractions are 0 or distances are infinite)
      # distribute probability equally or set to 0, depending on desired behavior.
      # Matching mod_huff.R behavior:
      puntos$prob <- rep(1/nrow(puntos), nrow(puntos))
    }
    
    return(puntos)
  }, error = function(e) {
    warning(paste("Error in huff_model:", e$message))
    # Return puntos with zero probability in case of error, or handle as appropriate
    puntos$prob <- rep(0, nrow(puntos))
    puntos$distancia <- Inf
    puntos$utilidad <- 0
    return(puntos)
  })
}
