# utils/google_places.R
# Funciones para interactuar con Google Places API.

library(httr)     # Para realizar solicitudes HTTP
library(jsonlite) # Para procesar respuestas JSON

#' Constante de Calificación por Defecto
#'
#' Valor numérico utilizado como calificación predeterminada cuando no se puede
#' obtener una calificación de Google Places (ej. el lugar no tiene calificación,
#' la API no responde, o hay un error).
DEFAULT_RATING <- 3.0 # Calificación neutral en una escala de 1-5. Se puede cambiar a NA si se prefiere.

#' Operador Coalescente para Nulos o Cadenas Vacías
#'
#' Devuelve `a` si `a` no es `NULL` y no es una cadena vacía (`""`).
#' En caso contrario, devuelve `b`. Útil para proporcionar valores por defecto.
#'
#' @param a El valor primario a verificar.
#' @param b El valor por defecto a devolver si `a` es `NULL` o `""`.
#' @return `a` o `b` según la condición.
#' @noRd
`%||%` <- function(a, b) {
  if (!is.null(a) && nzchar(a)) {
    a
  } else {
    b
  }
}

#' Obtener Calificación de un Lugar usando Google Places API
#'
#' Busca un lugar utilizando la API de Google Places (específicamente Text Search)
#' basándose en su nombre y coordenadas geográficas (latitud, longitud).
#' Luego, intenta extraer la calificación (rating) de dicho lugar.
#'
#' @param place_name El nombre del lugar a buscar (ej. "Restaurante El Sazón"). Tipo `character`.
#' @param lat Latitud del lugar. Tipo `numeric`.
#' @param lng Longitud del lugar. Tipo `numeric`.
#' @param api_key Clave de la API de Google Places. Por defecto, intenta obtenerla de la
#'        variable de entorno `GOOGLE_PLACES_API_KEY`. Tipo `character`.
#' @param radius Radio de búsqueda en metros alrededor de `lat`, `lng`. Por defecto es 50 metros
#'        para acotar la búsqueda a lugares muy cercanos a las coordenadas dadas. Tipo `numeric`.
#' @return La calificación numérica de Google Places (ej. 4.5) si se encuentra y está disponible.
#'         Devuelve `DEFAULT_RATING` si el lugar no se encuentra, no tiene calificación,
#'         la clave API falta/es inválida, o ocurre cualquier otro error durante la solicitud.
#' @export
#'
#' @examples
#' \dontrun{
#' # Es necesario configurar la variable de entorno GOOGLE_PLACES_API_KEY
#' # Sys.setenv(GOOGLE_PLACES_API_KEY = "TU_API_KEY_AQUI")
#'
#' rating1 <- get_google_place_rating("Torre Eiffel", 48.858370, 2.294481)
#' print(rating1)
#'
#' rating2 <- get_google_place_rating("Estadio Azteca", 19.3029, -99.1505)
#' print(rating2)
#' }
get_google_place_rating <- function(place_name, lat, lng, api_key = Sys.getenv("GOOGLE_PLACES_API_KEY"), radius = 50) {
  # Verificar si la API key está disponible
  if (!nzchar(api_key)) { # nzchar es más robusto que == ""
    warning("Google Places API key is missing. Returning default rating.", call. = FALSE)
    return(DEFAULT_RATING)
  }
  
  # Validar coordenadas
  if (!is.numeric(lat) || !is.numeric(lng) || is.na(lat) || is.na(lng) ||
      lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    warning(
      paste0("Invalid or missing coordinates for '", place_name, "'. Returning default rating."),
      call. = FALSE
    )
    return(DEFAULT_RATING)
  }
  
  # URL base para la API de Google Places (Text Search)
  search_url <- "https://maps.googleapis.com/maps/api/place/textsearch/json"
  
  # Parámetros de la consulta
  query_params <- list(
    query = place_name,
    location = paste(lat, lng, sep = ","), # Formato "latitud,longitud"
    radius = radius, # Radio en metros
    key = api_key
  )
  
  tryCatch({
    # Realizar la solicitud GET a la API
    res <- httr::GET(search_url, query = query_params, httr::timeout(10)) # Timeout de 10 segundos
    
    # Verificar el código de estado HTTP
    if (httr::status_code(res) != 200) {
      warning(
        paste0(
          "Google Places API (Text Search) request failed for '", place_name,
          "' with status: ", httr::status_code(res),
          ". Response: ", httr::content(res, "text", encoding = "UTF-8")
        ),
        call. = FALSE
      )
      return(DEFAULT_RATING)
    }
    
    # Procesar la respuesta JSON
    content_res <- httr::content(res, "text", encoding = "UTF-8")
    data_res <- jsonlite::fromJSON(content_res)
    
    # Analizar el estado de la respuesta de la API
    if (data_res$status == "OK" && length(data_res$results) > 0) {
      # Asumir que el primer resultado es el más relevante.
      place <- data_res$results[1, ]
      
      if (!is.null(place$rating) && is.numeric(place$rating)) {
        return(as.numeric(place$rating))
      } else {
        # warning(paste0("Place '", place_name, "' (ID: ", place$place_id %||% "N/A", ") found, but has no valid rating. Returning default rating."), call. = FALSE)
        return(DEFAULT_RATING) # Devuelve default si no hay rating o no es numérico
      }
      
    } else if (data_res$status == "ZERO_RESULTS") {
      # warning(paste0("Google Places API: No results found for '", place_name, "' near ", lat, ",", lng, ". Status: ", data_res$status), call. = FALSE)
      return(DEFAULT_RATING)
    } else {
      warning(
        paste0(
          "Google Places API (Text Search) error for '", place_name, "'. Status: ",
          data_res$status, ". Msg: ", data_res$error_message %||% "N/A"
        ),
        call. = FALSE
      )
      return(DEFAULT_RATING)
    }
    
  }, error = function(e) {
    warning(paste0("Error during Google Places API call for '", place_name, "': ", e$message), call. = FALSE)
    return(DEFAULT_RATING)
  })
}

# --- Ejemplos de Uso (para propósitos de prueba) ---
# Descomentar y ejecutar interactivamente para probar la función.
# Asegúrate de tener la variable de entorno GOOGLE_PLACES_API_KEY configurada.
#
# if (interactive()) {
#   # Sys.setenv(GOOGLE_PLACES_API_KEY = "YOUR_API_KEY_HERE") # Reemplaza con tu clave API real para probar
#   if (nzchar(Sys.getenv("GOOGLE_PLACES_API_KEY"))) {
#     message("Probando get_google_place_rating...")
#     test_rating_paris <- get_google_place_rating("Eiffel Tower", 48.858370, 2.294481)
#     print(paste("Rating for Eiffel Tower:", test_rating_paris))
#
#     test_rating_mexico <- get_google_place_rating("Museo Soumaya", 19.4406, -99.1818)
#     print(paste("Rating for Museo Soumaya:", test_rating_mexico))
#
#     test_rating_no_place <- get_google_place_rating("LugarInexistenteXYZ123", 17.06, -96.72)
#     print(paste("Rating for LugarInexistenteXYZ123:", test_rating_no_place))
#   } else {
#     warning("GOOGLE_PLACES_API_KEY no está configurada. Saltando ejemplos de get_google_place_rating.", call. = FALSE)
#   }
#
#   # Prueba del operador %||%
#   # message("Probando operador %||%:")
#   # print(NULL %||% "default")
#   # print("" %||% "default")
#   # print("actual" %||% "default")
# }