# utils/inegi_denue.R
# Este script contiene funciones para interactuar con la API DENUE del INEGI.

library(inegiR) # Paquete para interactuar con datos del INEGI (aunque aquí usamos httr directamente)
library(httr)     # Para realizar solicitudes HTTP
library(jsonlite) # Para procesar respuestas JSON

# Intenta obtener el token de INEGI de las variables de entorno al cargar el script.
# Es preferible que el token se pase como argumento a la función principal,
# pero esto puede servir como un fallback o para scripts que siempre usan el mismo token.
token_inegi_global <- Sys.getenv("INEGI_API_KEY")

#' Verificar si las Coordenadas están dentro de México
#'
#' Función auxiliar para determinar si un par de coordenadas (latitud, longitud)
#' se encuentran dentro de los límites geográficos aproximados de México.
#'
#' @param lat Latitud a verificar. Tipo `numeric` o `character` convertible a numérico.
#' @param lon Longitud a verificar. Tipo `numeric` o `character` convertible a numérico.
#' @return `TRUE` si las coordenadas están dentro de México, `FALSE` en caso contrario.
#' @noRd # No exportar esta función auxiliar.
.EstaEnMexico <- function(lat, lon) {
  # Validar y convertir a numérico
  lat_num <- suppressWarnings(as.numeric(lat))
  lon_num <- suppressWarnings(as.numeric(lon))

  if (is.na(lat_num) || is.na(lon_num)) {
    return(FALSE) # No numérico o no convertible
  }

  # Límites aproximados de México (pueden necesitar ajuste para mayor precisión)
  # Latitud: ~14.5 (sur) a ~32.7 (norte)
  # Longitud: ~-118.3 (oeste) a ~-86.7 (este)
  if (lat_num < 14.559507 || lat_num > 32.757120 ||
      lon_num > -86.708301 || lon_num < -118.312155) {
    return(FALSE)
  } else {
    return(TRUE)
  }
}

#' Consultar Negocios en DENUE de INEGI
#'
#' Realiza una consulta a la API DENUE de INEGI para obtener información sobre
#' unidades económicas (negocios) cercanas a una ubicación geográfica dada,
#' filtrando por palabra clave y radio de búsqueda.
#'
#' @param latitud Latitud del punto central de búsqueda. Tipo `numeric`.
#' @param longitud Longitud del punto central de búsqueda. Tipo `numeric`.
#' @param token Token de API para el servicio DENUE de INEGI. Por defecto, intenta
#'        usar `token_inegi_global` (cargado de `Sys.getenv("INEGI_API_KEY")`).
#'        Tipo `character`.
#' @param meters Radio de búsqueda en metros alrededor del punto central.
#'        Por defecto es 250 metros. Tipo `numeric`.
#' @param keyword Palabra clave para filtrar los negocios (ej. "restaurante", "todos").
#'        Por defecto es "todos". Tipo `character`.
#' @param timeout_sec Segundos máximos para esperar una respuesta de la API.
#'        Por defecto es 60 segundos. Tipo `numeric`.
#'
#' @return Un `data.frame` con la información de los negocios encontrados.
#'         Las columnas del `data.frame` corresponden a los campos devueltos por la API DENUE
#'         (ej. `Nombre`, `Latitud`, `Longitud`, `Clase_actividad`, etc.), convertidos a minúsculas.
#'         Devuelve un `data.frame` vacío si no se encuentran negocios, si las coordenadas
#'         están fuera de México, si el token es inválido, o si ocurre un error en la API.
#' @export
#'
#' @examples
#' \dontrun{
#' # Es necesario configurar la variable de entorno INEGI_API_KEY
#' # Sys.setenv(INEGI_API_KEY = "TU_TOKEN_INEGI_AQUI")
#' # token_valido <- Sys.getenv("INEGI_API_KEY")
#'
#' # Buscar restaurantes cerca de una ubicación en Oaxaca
#' # (Asegúrate que el token sea válido para que esto funcione)
#' # negocios_df <- inegi_denue(
#' #   latitud = 17.06, longitud = -96.72,
#' #   token = token_valido, keyword = "restaurantes", meters = 500
#' # )
#' # if (nrow(negocios_df) > 0) {
#' #   print(head(negocios_df[, c("nombre", "clase_actividad")]))
#' # } else {
#' #   print("No se encontraron restaurantes o hubo un error.")
#' # }
#'
#' # Buscar todos los negocios (puede ser una lista larga)
#' # todos_negocios <- inegi_denue(19.4326, -99.1332, token = token_valido, meters = 100)
#' # print(paste("Total de negocios encontrados:", nrow(todos_negocios)))
#' }
inegi_denue <- function(latitud,
                        longitud,
                        token = token_inegi_global,
                        meters = 250,
                        keyword = "todos",
                        timeout_sec = 60) {
  # Validar token
  if (!nzchar(token)) {
    warning("Token de API para INEGI DENUE no proporcionado o vacío. No se puede realizar la consulta.", call. = FALSE)
    return(data.frame())
  }

  # Verifica que las coordenadas estén dentro del territorio mexicano
  if (!.EstaEnMexico(latitud, longitud)) {
    warning("Las coordenadas proporcionadas están fuera de México. No se realizará la consulta.", call. = FALSE)
    return(data.frame()) # Devolver dataframe vacío
  }
  
  # Construcción de la URL para la API DENUE
  base_url <- "https://www.inegi.org.mx/app/api/denue/v1/consulta/Buscar/"
  # La URL debe ser: Buscar/{palabrasClave}/{coordenadas}/{metros}/{token}
  consulta_url <- paste0(
    base_url, utils::URLencode(keyword), "/",
    latitud, ",", longitud, "/", meters, "/", token
  )
  
  # Solicitud con timeout y manejo de error
  respuesta <- tryCatch({
    r <- httr::GET(consulta_url, httr::timeout(timeout_sec))
    
    # Verificar código de estado HTTP
    if (httr::status_code(r) != 200) {
      error_content <- httr::content(r, "text", encoding = "UTF-8")
      warning(
        paste("La API DENUE respondió con código:", httr::status_code(r), ". Mensaje:", error_content),
        call. = FALSE
      )
      return(NULL) # Indicar fallo en la solicitud
    }
    
    # Obtener contenido de la respuesta
    httr::content(r, as = "text", encoding = "UTF-8")
    
  }, error = function(e) {
    warning(paste("Error en la conexión o timeout con la API DENUE:", conditionMessage(e)), call. = FALSE)
    return(NULL) # Indicar fallo en la conexión/timeout
  })
  
  # Si no hubo respuesta o está vacía
  if (is.null(respuesta) || !nzchar(respuesta)) {
    return(data.frame()) # Devolver dataframe vacío
  }
  
  # Convertir JSON a data.frame
  datos <- tryCatch({
    df <- jsonlite::fromJSON(respuesta)
    if (is.null(df) || length(df) == 0) {
      return(data.frame())
    }
    as.data.frame(df, stringsAsFactors = FALSE)
  }, error = function(e) {
    warning(paste("No se pudo parsear el JSON de la respuesta de DENUE:", conditionMessage(e)), call. = FALSE)
    return(data.frame()) # Devolver dataframe vacío en caso de error de parseo
  })
  
  # Estandarizar nombres de columnas a minúsculas si el dataframe no está vacío
  if (nrow(datos) > 0) {
    names(datos) <- tolower(names(datos))
  }

  return(datos)
}
