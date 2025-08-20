# Módulo Mapa con hexbin, ubicación, búsqueda DENUE y socioeconómico

mod_mapa_ui <- function(id) {
  ns <- NS(id) # Standard namespace convention
  tagList(
    fluidRow(
      column(
        width = 8,
        # Increased map height to be responsive and fill more of the screen
        # Adjusted to calc(100vh - 70px) to account for dashboard header and some margin
        leafletOutput(ns("mapa"), height = "calc(100vh - 70px)"),
        # br(), # Consider removing <br> if map takes full height of this column
        actionButton(ns("get_location"), "Obtener mi ubicación"),
        actionButton(ns("reset_mapa"), "Borrar marcadores y centrar mapa"),
        checkboxInput(ns("mostrar_hexbin"), "Mostrar hexágonos", value = TRUE),
        # Apply the 'controls' class to this wellPanel
        wellPanel(class = "controls",
          h4("Controles del Mapa"), # Added header for styling
          div(class = "wellPanel-content",
              textInput(ns("estado"), "Estado:", "Oaxaca"), # Default state, consider making configurable if needed
              selectizeInput(ns("municipio"), "Municipio:", choices = NULL, options = list(placeholder = "Escriba un municipio...", create = TRUE)), # choices = NULL for server-side update, create = TRUE allows new entries
              selectizeInput(ns("localidad"), "Localidad:", choices = NULL, options = list(placeholder = "Escriba una localidad...", create = TRUE)), # choices = NULL for server-side update
              actionButton(ns("centrar"), "Centrar mapa"),
              hr(),
              textInput(ns("palabra_clave"), "Palabra clave (ej. joyería, boutique):",
                        value = APP_CONFIG$map_search_keyword_default), # From APP_CONFIG
              numericInput(ns("radio"), "Radio de búsqueda (m):",
                           value = APP_CONFIG$map_search_radius_default, # From APP_CONFIG
                           min = 100, step = 100),
              actionButton(ns("buscar"), "Buscar negocios"),
              # Custom JS for geolocation
              tags$script(HTML(paste0(
                "Shiny.addCustomMessageHandler('get_location_", id, "', function(message) {
                  if (navigator.geolocation) {
                    navigator.geolocation.getCurrentPosition(
                      function(position) {
                        Shiny.setInputValue('", ns("location"), "', {
                          lat: position.coords.latitude,
                          lon: position.coords.longitude
                        });
                      },
                      function() {
                        alert('No se pudo obtener la ubicación. Por favor, verifica los permisos.');
                      }
                    );
                  } else {
                    alert('La geolocalización no es soportada por este navegador.');
                  }
                });"
              ))) # End tags$script
          ) # End div
        ) # End wellPanel
      ), # End column
      column(
        width = 4,
        selectInput(
          ns("variable"),
          "Perfil del cliente:",
          choices = c( # These could also be moved to APP_CONFIG if they change often
            "Joven Digital" = "joven_digital",
            "Mamá Emprendedora" = "mama_emprendedora",
            "Mayorista Experimentado" = "mayorista_experimentado",
            "Cliente Potencial" = "clientes_totales"
          ),
          selected = "clientes_totales" # Default selected variable
        ),
        plotOutput(ns("histograma")) # Output for histogram
      ) # End column
    ) # End fluidRow
  ) # End tagList
}

mod_mapa_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Initial population of selectize inputs for Municipio and Localidad
    # This runs once when the module is initialized.
    if (exists("agebs_hex") && inherits(agebs_hex, "sf") &&
        all(c("nombre_municipio", "nombre_localidad") %in% names(agebs_hex))) {

        # Get unique, sorted municipio names, excluding NA or empty strings
        mun_choices <- unique(agebs_hex$nombre_municipio)
        mun_choices <- sort(mun_choices[!is.na(mun_choices) & nzchar(trimws(mun_choices))])
        updateSelectizeInput(session, "municipio", choices = mun_choices, selected = "", server = TRUE)

        # Get unique, sorted localidad names, excluding NA or empty strings
        loc_choices <- unique(agebs_hex$nombre_localidad)
        loc_choices <- sort(loc_choices[!is.na(loc_choices) & nzchar(trimws(loc_choices))])
        updateSelectizeInput(session, "localidad", choices = loc_choices, selected = "", server = TRUE)
    } else {
        warning("mod_mapa_server: agebs_hex data is not available or missing required columns for selectize inputs at initialization.")
        updateSelectizeInput(session, "municipio", choices = character(0), selected = "", server = TRUE)
        updateSelectizeInput(session, "localidad", choices = character(0), selected = "", server = TRUE)
    }
    
    # Reactive values
    user_location <- reactiveVal(NULL)
    clicked_coordinates <- reactiveVal(NULL) # For storing map click coordinates
    # Initialize map center with default coordinates from APP_CONFIG
    centro <- reactiveVal(c(lat = APP_CONFIG$default_lat, lng = APP_CONFIG$default_lng))
    negocios_data <- reactiveVal(data.frame()) # Stores data for businesses

    # Dynamic update of Localidad choices based on selected Municipio
    observeEvent(input$municipio, {
        selected_mun <- input$municipio

        # Ensure agebs_hex is available for dynamic updates too
        if (exists("agebs_hex") && inherits(agebs_hex, "sf") &&
            all(c("nombre_municipio", "nombre_localidad") %in% names(agebs_hex))) {

            current_loc_val <- input$localidad # Preserve current localidad if possible

            if (!is.null(selected_mun) && nzchar(trimws(selected_mun))) {
                # Filter localities based on the selected municipio
                # Ensure case-insensitive comparison for municipio name
                filtered_loc_choices <- unique(
                    agebs_hex$nombre_localidad[tolower(trimws(as.character(agebs_hex$nombre_municipio))) == tolower(trimws(selected_mun))]
                )
                filtered_loc_choices <- sort(filtered_loc_choices[!is.na(filtered_loc_choices) & nzchar(trimws(filtered_loc_choices))])

                # Decide selected value for localidad
                selected_loc_val <- if (!is.null(current_loc_val) && current_loc_val %in% filtered_loc_choices) {
                                        current_loc_val
                                    } else {
                                        "" # Or filtered_loc_choices[1] if you want to auto-select the first
                                    }

                if (length(filtered_loc_choices) == 0) {
                    # If no specific localities, show all localities or an empty list.
                    # For consistency, let's show all if the specific filter yields none.
                    all_loc_choices <- unique(agebs_hex$nombre_localidad)
                    all_loc_choices <- sort(all_loc_choices[!is.na(all_loc_choices) & nzchar(trimws(all_loc_choices))])
                    updateSelectizeInput(session, "localidad", choices = all_loc_choices, selected = "", server = TRUE)
                    # Optional: Notify user if specific localities for a municipio are expected but not found
                    # showNotification("No localidades específicas para este municipio, mostrando todas.", type="info", duration=3)
                } else {
                   updateSelectizeInput(session, "localidad", choices = filtered_loc_choices, selected = selected_loc_val, server = TRUE)
                }
            } else {
                # If municipio is cleared/empty, reset localidad to all choices
                all_loc_choices <- unique(agebs_hex$nombre_localidad)
                all_loc_choices <- sort(all_loc_choices[!is.na(all_loc_choices) & nzchar(trimws(all_loc_choices))])
                updateSelectizeInput(session, "localidad", choices = all_loc_choices, selected = "", server = TRUE)
            }
        } else {
            warning("mod_mapa_server: agebs_hex data not available for dynamic localidad update.")
            # Potentially disable or clear localidad input if agebs_hex is missing
            updateSelectizeInput(session, "localidad", choices = character(0), selected = "", server = TRUE)
        }
    }, ignoreNULL = FALSE, ignoreInit = TRUE) # ignoreNULL=FALSE to react to clearing; ignoreInit=TRUE for initial setup
    
    # Handle geolocation
    observeEvent(input$get_location, {
      session$sendCustomMessage(paste0("get_location_", id), list())
    })
    
    observeEvent(input$location, {
      if (!is.null(input$location)) {
        user_location(input$location)
        centro(c(lat = input$location$lat, lng = input$location$lon))
      }
    })
    
    # Center map based on text inputs using get_centroid_for_area
    observeEvent(input$centrar, {
      mun_name <- input$municipio
      loc_name <- input$localidad

      # Check if both inputs are empty or NULL
      if ((is.null(mun_name) || !nzchar(trimws(mun_name))) &&
          (is.null(loc_name) || !nzchar(trimws(loc_name)))) {
        showNotification("Por favor, ingrese un nombre de municipio y/o localidad para centrar.", type = "warning", duration = 5)
        return()
      }

      # Ensure agebs_hex is available and valid
      if (!exists("agebs_hex") || !inherits(agebs_hex, "sf")) {
          showNotification("Error crítico: Datos geográficos base (agebs_hex) no están disponibles o son inválidos.", type = "error", duration = 7)
          return()
      }
      if (!all(c("nombre_municipio", "nombre_localidad") %in% names(agebs_hex))) {
          showNotification("Error crítico: Columnas 'nombre_municipio' o 'nombre_localidad' ausentes en datos geográficos.", type = "error", duration = 7)
          # This check is more for development; previous subtasks should ensure columns exist.
          return()
      }

      # Renamed to new_center_coords_list to match prompt and avoid potential conflicts
      new_center_coords_list <- get_centroid_for_area(
        municipio_name = mun_name,
        localidad_name = loc_name,
        sf_data = agebs_hex
      )

      if (!is.null(new_center_coords_list) &&
          is.numeric(new_center_coords_list$lat) && is.numeric(new_center_coords_list$lng)) {

        current_lat <- new_center_coords_list$lat
        current_lng <- new_center_coords_list$lng

        centro(c(lat = current_lat, lng = current_lng))

        # Store these coordinates as the new 'active' point for search
        clicked_coordinates(list(lat = current_lat, lng = current_lng))

        # Add/Update the 'selected_point_marker' at the centroid location
        leafletProxy("mapa") %>%
          clearGroup("selected_point_marker") %>% # Clear previous selection marker
          addAwesomeMarkers(
            lng = current_lng,
            lat = current_lat,
            icon = awesomeIcons(icon = "crosshairs", library = "fa", markerColor = "blue", iconColor = "#FFF"), # Different icon/color for centroid
            group = "selected_point_marker",
            layerId = "centroid_location_marker"
          ) %>%
          setView(lng = current_lng, lat = current_lat, zoom = 14)

        area_message_parts <- c()
        if (nzchar(trimws(mun_name))) area_message_parts <- c(area_message_parts, paste("Municipio:", mun_name))
        if (nzchar(trimws(loc_name))) area_message_parts <- c(area_message_parts, paste("Localidad:", loc_name))
        area_string <- paste(area_message_parts, collapse = ", ")

        showNotification(paste("Mapa centrado en:", area_string, ". Este punto está activo para la búsqueda."), type = "message", duration = 6)
      } else {
        # Construct a detailed warning message
        warning_message_parts <- c("No se pudo encontrar o calcular el centro para:")
        if (nzchar(trimws(mun_name))) warning_message_parts <- c(warning_message_parts, paste("Municipio '", mun_name,"'", sep=""))
        if (nzchar(trimws(loc_name))) warning_message_parts <- c(warning_message_parts, paste("Localidad '", loc_name,"'", sep=""))
        warning_message <- paste(warning_message_parts, collapse = ", ")
        showNotification(
          paste0(warning_message, ". Verifique los nombres e inténtelo de nuevo."),
          type = "warning",
          duration = 7
        )
      }
    })
    
    # Reset map markers and view
    observeEvent(input$reset_mapa, {
      negocios_data(data.frame()) # Clear business data
      user_location(NULL) # Clear user location
      clicked_coordinates(NULL) # Clear clicked coordinates

      # Reset to default center from APP_CONFIG
      centro(c(lat = APP_CONFIG$default_lat, lng = APP_CONFIG$default_lng))

      leafletProxy("mapa") %>%
        clearGroup("markers") %>% # Clears business markers
        clearGroup("selected_point_marker") %>% # Clears the map click marker
        setView(lng = APP_CONFIG$default_lng, lat = APP_CONFIG$default_lat, zoom = 13) # Use APP_CONFIG
    })
    
    # Observer for map clicks (New behavior: only select point, do not search)
    observeEvent(input$mapa_click, {
      req(input$mapa_click) # Ensure click data is available

      # Store clicked coordinates
      coords <- list(lat = input$mapa_click$lat, lng = input$mapa_click$lng)
      clicked_coordinates(coords)

      # Add a marker for the selected point
      # Use a specific group for this marker, e.g., "selected_point_marker"
      # Clear previous marker in this group first
      leafletProxy("mapa") %>%
        clearGroup("selected_point_marker") %>%
        addAwesomeMarkers(
          lng = coords$lng,
          lat = coords$lat,
          icon = awesomeIcons(icon = "map-marker", library = "fa", markerColor = "red", iconColor = "#FFF"),
          group = "selected_point_marker",
          layerId = "clicked_location_marker" # Add a layerId for potential future direct manipulation
        )

      showNotification("Punto seleccionado en el mapa. Use 'Buscar negocios' para encontrar negocios aquí.", type = "message", duration = 5)

      # Update map center to the clicked point for visual feedback
      centro(c(lat = coords$lat, lng = coords$lng))
    })
    
    # Search for businesses
    observeEvent(input$buscar, {
      search_lat <- NULL
      search_lng <- NULL
      search_source_message <- ""

      # Determine coordinates for the search
      if (!is.null(clicked_coordinates())) {
        search_lat <- clicked_coordinates()$lat
        search_lng <- clicked_coordinates()$lng
        search_source_message <- "el punto previamente seleccionado"
        # Optional: Clear clicked_coordinates() after use if it's a one-time use.
        # For now, kept persistent until a new click or centering.
        # clicked_coordinates(NULL)
        # leafletProxy("mapa") %>% clearGroup("selected_point_marker")
      } else if (!is.null(centro())) { # Fallback to current map center
        # Ensure centro() gives list(lat, lng) or c(lat, lng)
        # Assuming centro() is c(lat = val, lng = val) or list(lat = val, lng = val)
        if (is.list(centro()) && !is.null(centro()$lat) && !is.null(centro()$lng)) {
            search_lat <- centro()$lat
            search_lng <- centro()$lng
        } else if (is.numeric(centro()) && length(centro()) == 2 && !is.null(names(centro())) && all(names(centro()) %in% c("lat", "lng"))) {
            search_lat <- centro()["lat"]
            search_lng <- centro()["lng"]
        } else if (is.numeric(centro()) && length(centro()) == 2) { # Fallback if unnamed c(lat,lng)
            search_lat <- centro()[1]
            search_lng <- centro()[2]
            warning("centro() was an unnamed vector, assuming order lat, lng. Named list or vector is preferred.")
        }
        search_source_message <- "el centro actual del mapa"
      } else {
        showNotification("No hay un punto de referencia para la búsqueda (ni clic, ni centro de mapa).", type = "error", duration = 5)
        return()
      }

      if (is.null(search_lat) || is.null(search_lng) || !is.numeric(search_lat) || !is.numeric(search_lng)) {
        showNotification("Coordenadas para la búsqueda no válidas o no numéricas.", type = "error", duration = 5)
        return()
      }
      
      showNotification(paste("Iniciando búsqueda de negocios en", search_source_message,
                             ": (", round(search_lat, 5), ", ", round(search_lng, 5), ")"),
                       type = "message", duration = 3)

      tryCatch({
        token_valido <- Sys.getenv("INEGI_API_KEY")
        
        if (!nzchar(token_valido)) {
          n_negocios_sim <- sample(5:15, 1)
          sim_data <- data.frame(
            nombre = paste("Negocio Simulado (búsqueda)", 1:n_negocios_sim),
            latitud = search_lat + runif(n_negocios_sim, -0.005, 0.005),
            longitud = search_lng + runif(n_negocios_sim, -0.005, 0.005),
            stringsAsFactors = FALSE
          )
          negocios_data(sim_data)
          showNotification(
            paste("API Key de INEGI no encontrada. Mostrando", n_negocios_sim, "negocios simulados cerca de", search_source_message,"."),
            type = "warning", duration = 5
          )
        } else {
          tipos_busqueda <- trimws(unlist(strsplit(input$palabra_clave, ",")))
          radio_busqueda <- input$radio
          
          negocios_encontrados <- data.frame()
          for (tipo_kw_busqueda in tipos_busqueda) {
            if (nzchar(tipo_kw_busqueda)) {
              res_busqueda <- tryCatch({
                inegi_denue(
                  latitud = search_lat,
                  longitud = search_lng,
                  token = token_valido,
                  meters = radio_busqueda,
                  keyword = tipo_kw_busqueda
                )
              }, error = function(e) {
                showNotification(paste("Error al llamar a INEGI DENUE para '", tipo_kw_busqueda, "': ", e$message), type = "error", duration = 7)
                return(data.frame())
              })

              if (nrow(res_busqueda) > 0) {
                negocios_encontrados <- rbind(negocios_encontrados, res_busqueda)
              }
            }
          }
          
          if (nrow(negocios_encontrados) > 0) {
            negocios_encontrados <- unique(negocios_encontrados)
          }

          negocios_data(negocios_encontrados)
          
          if (nrow(negocios_encontrados) == 0) {
            showNotification(paste("No se encontraron negocios para la palabra clave '", input$palabra_clave, "' cerca de", search_source_message, "."), type = "warning", duration = 5)
          } else {
            showNotification(paste("Se encontraron", nrow(negocios_encontrados), "negocios para '", input$palabra_clave, "' cerca de", search_source_message, "."), type = "message", duration = 5)
          }
        }
      }, error = function(e) {
        showNotification(paste("Error general durante la búsqueda de negocios:", e$message), type = "error", duration = 7)
        message("Error en observeEvent input$buscar: ", e$message)
      })
    })
    
    # Render base map
    output$mapa <- renderLeaflet({
      leaflet() %>%
        addProviderTiles("CartoDB.Positron") %>%
        setView(lng = centro()[2], lat = centro()[1], zoom = 13)
    })
    
    # Observe changes for hexbin display
    observe({
      req(input$mostrar_hexbin, input$variable, agebs_hex) # Ensure all inputs are available
      
      variable_data <- agebs_hex[[input$variable]]
      if (all(is.na(variable_data))) {
        variable_data <- rep(0, nrow(agebs_hex))
        showNotification("Datos para el perfil seleccionado no disponibles o todos NA.", type = "warning")
      }
      
      pal <- colorNumeric("YlGn", domain = variable_data, na.color = "transparent")
      
      leafletProxy("mapa") %>%
        clearGroup("hex") %>%
        addPolygons(
          data = agebs_hex,
          fillColor = ~ pal(variable_data),
          fillOpacity = 0.6,
          color = "white",
          weight = 1,
          popup = ~ paste0(
            "<b>ID Hex: ", id_hex, 
            "</b><br>", "Población Total: ", poblacion_total, "<br>",
            input$variable, ": ", round(variable_data)
          ),
          group = "hex"
        )
    })
    
    # Clear hexbins if checkbox is unchecked
    observe({
      if (!input$mostrar_hexbin) {
        leafletProxy("mapa") %>% clearGroup("hex")
      }
    })
    
    
    # Update markers for businesses and user location
    observe({
      proxy <- leafletProxy("mapa")
      proxy %>% clearGroup("markers")
      
      if (!is.null(user_location())) {
        proxy %>%
          addAwesomeMarkers(
            lng = user_location()$lon,
            lat = user_location()$lat,
            popup = "¡Aquí estás tú!",
            icon = awesomeIcons(icon = "user", library = "fa", markerColor = "green"),
            group = "markers"
          )
      }
      
      if (nrow(negocios_data()) > 0) {
        negocios <- negocios_data()
        
        lat_col <- if ("latitud" %in% names(negocios)) "latitud" else if ("lat" %in% names(negocios)) "lat" else NULL
        lng_col <- if ("longitud" %in% names(negocios)) "longitud" else if ("lng" %in% names(negocios)) "lng" else NULL
        name_col <- if ("nombre" %in% names(negocios)) "nombre" else if ("Nombre" %in% names(negocios)) "Nombre" else names(negocios)[1]
        
        if (!is.null(lat_col) && !is.null(lng_col)) {
          proxy %>%
            addMarkers(
              data = negocios,
              lng = ~ as.numeric(get(lng_col)),
              lat = ~ as.numeric(get(lat_col)),
              popup = ~ as.character(get(name_col)),
              group = "markers"
            )
        }
      }
    })
    
    # Render histogram for selected socio-economic variable
    output$histograma <- renderPlot({
      req(input$variable, agebs_hex)
      
      variable_data <- agebs_hex[[input$variable]]
      if (all(is.na(variable_data) | !is.numeric(variable_data))) {
        plot(0, 0, type = "n", axes = FALSE, xlab = "", ylab = "")
        text(0, 0, "Datos no disponibles o no numéricos para el histograma.", cex = 1.2)
        return()
      }
      
      hist(
        variable_data,
        col = "#7A9E7E",
        border = "white",
        main = paste("Distribución de:", input$variable),
        xlab = gsub("_", " ", Hmisc::capitalize(input$variable)),
        ylab = "Frecuencia"
      )
    })
  }) # End moduleServer
}
