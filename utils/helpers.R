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

# Ensure sf is loaded if not already (though global.R should handle this)
# if (!requireNamespace("sf", quietly = TRUE)) {
#   stop("Package 'sf' needed for this function to work.")
# }

get_centroid_for_area <- function(municipio_name = NULL, localidad_name = NULL, sf_data) {
  if (missing(sf_data) || !inherits(sf_data, "sf")) {
    stop("sf_data must be an sf object.")
  }
  if (!all(c("nombre_municipio", "nombre_localidad") %in% names(sf_data))) {
    stop("sf_data must contain 'nombre_municipio' and 'nombre_localidad' columns.")
  }

  # Normalize inputs
  mun_query <- if (!is.null(municipio_name) && nzchar(trimws(municipio_name))) trimws(tolower(municipio_name)) else NULL
  loc_query <- if (!is.null(localidad_name) && nzchar(trimws(localidad_name))) trimws(tolower(localidad_name)) else NULL

  if (is.null(mun_query) && is.null(loc_query)) {
    # message("No municipio or localidad name provided for centroid calculation.")
    return(NULL)
  }

  filtered_data <- sf_data

  if (!is.null(mun_query)) {
    # Ensure case-insensitive matching for sf_data columns as well
    filtered_data <- filtered_data[tolower(trimws(as.character(filtered_data$nombre_municipio))) == mun_query, ]
  }

  if (nrow(filtered_data) == 0 && !is.null(mun_query)) {
    # message(paste("No areas found matching municipio:", municipio_name))
    return(NULL)
  }

  if (!is.null(loc_query)) {
    # If municipio was also specified, filter within that result. Otherwise, filter whole dataset.
    # Ensure case-insensitive matching for sf_data columns as well
    filtered_data <- filtered_data[tolower(trimws(as.character(filtered_data$nombre_localidad))) == loc_query, ]
  }

  if (nrow(filtered_data) == 0) {
    # message(paste("No areas found for specified criteria. Municipio:", municipio_name, "Localidad:", localidad_name))
    return(NULL)
  }

  # Combine geometries if multiple rows matched
  # Use st_geometry to ensure we are working with geometry column
  if (nrow(filtered_data) == 1) {
    combined_geometry <- sf::st_geometry(filtered_data)
  } else {
    # Dissolve borders for all matching polygons
    combined_geometry <- sf::st_union(sf::st_geometry(filtered_data))
  }

  # Calculate centroid
  # st_centroid can sometimes fail if geometry is invalid; add error handling
  centroid_sf <- tryCatch({
    sf::st_centroid(combined_geometry)
  }, error = function(e) {
    warning(paste("Error calculating centroid for area (Municipio:", municipio_name, ", Localidad:", localidad_name, "): ", e$message))
    return(NULL)
  })

  if (is.null(centroid_sf) || length(sf::st_coordinates(centroid_sf)) == 0) {
    warning(paste("Centroid calculation resulted in NULL or empty coordinates for (Municipio:", municipio_name, ", Localidad:", localidad_name, ")"))
    return(NULL)
  }

  coords <- sf::st_coordinates(centroid_sf)

  # Ensure coords is not empty or malformed before accessing
  if (nrow(coords) > 0 && all(c("X", "Y") %in% colnames(coords))) {
    return(c(lat = coords[1, "Y"], lng = coords[1, "X"]))
  } else {
    warning(paste("Failed to extract valid X, Y coordinates from centroid for (Municipio:", municipio_name, ", Localidad:", localidad_name, ")"))
    return(NULL)
  }
}
