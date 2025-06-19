# utils/huff_model.R

# Para usar Google Places para obtener el 'atractivo' (ej. rating),
# se necesitaría integrar la función de 'utils/google_places.R'
# y modificar la lógica de 'atractivo' en los datos de entrada.
# source('utils/google_places.R')

library(geosphere) # Para cálculo de distancias geográficas precisas

#' Calcula la Probabilidad de Captación Usando el Modelo de Huff
#'
#' Esta función implementa el modelo de Huff para estimar la probabilidad de que
#' un punto de demanda (ej. un AGEB o ubicación de cliente) sea atraído por
#' diferentes puntos de oferta (ej. tiendas, servicios). La probabilidad se basa
#' en el atractivo de cada punto de oferta y la distancia entre el punto de demanda
#' y cada punto de oferta.
#'
#' @param ag_lat Latitud del punto de demanda (ej. centroide del AGEB). Valor numérico.
#' @param ag_lng Longitud del punto de demanda. Valor numérico.
#' @param puntos Un `data.frame` que representa los puntos de oferta. Debe contener
#'        columnas `lat` (latitud), `lng` (longitud), `id` (identificador único del punto),
#'        y `atractivo` (medida de atractivo del punto, ej. tamaño, calificación).
#' @param alfa Parámetro de sensibilidad al atractivo. Controla la importancia del
#'        factor de atractivo en el modelo. Por defecto es 1. Valor numérico.
#' @param beta Parámetro de fricción de la distancia. Controla cómo la distancia
#'        afecta la probabilidad (valores más altos significan mayor disuasión
#'        por la distancia). Por defecto es 2. Valor numérico.
#'
#' @return Un `data.frame` igual al `puntos` de entrada, pero con columnas adicionales:
#'         `distancia` (distancia en km desde `ag_lat`, `ag_lng` al punto),
#'         `utilidad` (valor de utilidad calculado por el modelo), y
#'         `prob` (probabilidad de captación para cada punto de oferta).
#'         En caso de error, devuelve el `data.frame` `puntos` con `prob` igual a 0,
#'         `distancia` a Inf, y `utilidad` a 0.
#' @export
#'
#' @examples
#' # Puntos de oferta (ej. tiendas)
#' tiendas <- data.frame(
#'   id = c("Tienda A", "Tienda B", "Tienda C"),
#'   lat = c(17.07, 17.05, 17.08),
#'   lng = c(-96.73, -96.71, -96.70),
#'   atractivo = c(100, 150, 80) # Ej. metros cuadrados de la tienda
#' )
#'
#' # Punto de demanda (ej. ubicación de un cliente)
#' cliente_lat <- 17.06
#' cliente_lng <- -96.72
#'
#' # Calcular probabilidades de Huff
#' resultados_huff <- huff_model(cliente_lat, cliente_lng, tiendas, alfa = 1, beta = 2)
#' print(resultados_huff)
huff_model <- function(ag_lat, ag_lng, puntos, alfa = 1, beta = 2) {
  # puntos: data.frame con lat, lng, id, atractivo
  # ag_lat, ag_lng: latitude and longitude of the current demand point (e.g., AGEB)
  # alfa: attraction parameter
  # beta: distance friction parameter

  tryCatch({
    # Validar entradas básicas
    if (!is.numeric(ag_lat) || !is.numeric(ag_lng)) {
      stop("Coordenadas del punto de demanda (ag_lat, ag_lng) deben ser numéricas.")
    }
    if (!is.data.frame(puntos) || !all(c("lat", "lng", "atractivo") %in% names(puntos))) {
      stop("La entrada 'puntos' debe ser un data.frame con columnas 'lat', 'lng', y 'atractivo'.")
    }
    if (nrow(puntos) == 0) {
      # Si no hay puntos de oferta, devolver el dataframe vacío con las columnas esperadas
      puntos$distancia <- numeric(0)
      puntos$utilidad <- numeric(0)
      puntos$prob <- numeric(0)
      return(puntos)
    }
    if (!is.numeric(puntos$lat) || !is.numeric(puntos$lng) || !is.numeric(puntos$atractivo)) {
      stop("Las columnas 'lat', 'lng' y 'atractivo' en 'puntos' deben ser numéricas.")
    }

    # Calculate distances using geosphere for mayor precision
    # distHaversine devuelve metros, se convierte a km
    puntos$distancia <- geosphere::distHaversine(
      cbind(puntos$lng, puntos$lat), # Matriz de longitudes y latitudes de los puntos de oferta
      c(ag_lng, ag_lat)              # Vector con longitud y latitud del punto de demanda
    ) / 1000 # Convertir a km

    # Evitar división por cero o distancias muy pequeñas si el punto de demanda coincide con un punto de oferta
    puntos$distancia[puntos$distancia == 0] <- 0.001 # Asignar una distancia mínima (ej. 1 metro)
    
    # Calcular utilidad con parámetros alfa y beta
    # Asegurarse que el atractivo no sea negativo si alfa no es entero
    puntos$utilidad <- (puntos$atractivo^alfa) / (puntos$distancia^beta)
    
    # Calcular probabilidades
    total_utilidad <- sum(puntos$utilidad, na.rm = TRUE)

    if (total_utilidad > 0) {
      puntos$prob <- puntos$utilidad / total_utilidad
    } else {
      # Si total_utilidad es 0 (ej. todas las atracciones son 0 o las distancias son infinitas),
      # se asigna probabilidad igual a cada punto, o 0 si no hay puntos.
      # Este comportamiento es consistente con mod_huff.R.
      if (nrow(puntos) > 0) {
        puntos$prob <- rep(1 / nrow(puntos), nrow(puntos))
      } else {
        puntos$prob <- numeric(0) # Si no hay puntos, probabilidad es un vector numérico vacío
      }
    }

    return(puntos)

  }, error = function(e) {
    warning(paste("Error en huff_model:", e$message), call. = FALSE)
    # Devolver el data.frame 'puntos' con columnas de error en caso de fallo
    puntos$distancia <- Inf
    puntos$utilidad <- 0
    puntos$prob <- rep(0, nrow(puntos)) # Probabilidad cero para todos los puntos
    return(puntos)
  })
}
