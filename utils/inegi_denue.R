# Función para consultar negocios usando palabras clave y radio con API DENUE (simulada)

# utils/inegi_denue.R
# Función simulada para obtener negocios cercanos desde el DENUE

library(inegiR)
library(httr)
library(jsonlite)

token_inegi <- Sys.getenv("INEGI_API_KEY")

inegi_denue <- function(latitud, longitud, token = token_inegi , meters = 250, keyword = "todos", timeout_sec = 60) {
  
  # Verifica que las coordenadas estén dentro del territorio mexicano
  .EstaEnMexico <- function(lat, lon) {
    if (as.numeric(lat) < 14.559507 | as.numeric(lat) > 32.757120 |
        as.numeric(lon) > -86.708301 | as.numeric(lon) < -118.312155) {
      return(FALSE)
    } else {
      return(TRUE)
    }
  }
  
  if (!.EstaEnMexico(latitud, longitud)) {
    stop("Coordinates are not in Mexico")
  }
  
  # Construcción de la URL
  base_url <- "https://www.inegi.org.mx/app/api/denue/v1/consulta/Buscar/"
  consulta_url <- paste0(base_url, keyword, "/", latitud, ",", longitud, "/", meters, "/", token)
  
  # Solicitud con timeout y manejo de error
  respuesta <- tryCatch({
    r <- GET(consulta_url, timeout(timeout_sec))
    
    if (status_code(r) != 200) {
      warning(paste("La API respondió con código:", status_code(r)))
      return(NULL)
    }
    
    content(r, as = "text", encoding = "UTF-8")
    
  }, error = function(e) {
    warning(paste("Error en la conexión o timeout:", conditionMessage(e)))
    return(NULL)
  })
  
  # Si no hubo respuesta o está vacía
  if (is.null(respuesta) || respuesta == "") {
    return(data.frame())
  }
  
  # Convertir JSON a data.frame
  datos <- tryCatch({
    df <- fromJSON(respuesta)
    if (length(df) == 0) return(data.frame())
    as.data.frame(df, stringsAsFactors = FALSE)
  }, error = function(e) {
    warning("No se pudo parsear el JSON.")
    return(data.frame())
  })
  
  names(datos) <- tolower(names(datos))
  return(datos)
}
