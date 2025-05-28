# utils/helpers.R
# Funciones auxiliares para inputs, centrado, validación, etc.

centrar_en <- function(nombre, tipo = c("estado", "municipio", "localidad")) {
  # Solo simulado
  switch(nombre,
         "Oaxaca" = c(lat = 17.06, lon = -96.72),
         "Puerto Escondido" = c(lat = 15.86, lon = -97.08),
         "Huejutla" = c(lat = 21.13, lon = -98.42),
         c(lat = 17.06, lon = -96.72)) # default
}
