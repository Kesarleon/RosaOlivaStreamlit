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
          textInput(ns("estado"), "Estado:", "Oaxaca"), # Default state, consider making configurable if needed
          textInput(ns("municipio"), "Municipio:", ""),
          textInput(ns("localidad"), "Localidad:", ""),
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
    
    # Reactive values
    user_location <- reactiveVal(NULL)
    # Initialize map center with default coordinates from APP_CONFIG
    centro <- reactiveVal(c(lat = APP_CONFIG$default_lat, lng = APP_CONFIG$default_lng))
    negocios_data <- reactiveVal(data.frame()) # Stores data for businesses
    
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
    
    # Center map based on text inputs (simulated)
    observeEvent(input$centrar, {
      # This is a placeholder for actual geocoding functionality
      # For now, it just slightly jitters the current center or a default if not set
      current_center <- if (!is.null(centro())) centro() else c(lat = APP_CONFIG$default_lat, lng = APP_CONFIG$default_lng)
      new_center <- c(
        lat = current_center[1] + runif(1, -0.01, 0.01), # Slight random shift for demo
        lng = current_center[2] + runif(1, -0.01, 0.01)
      )
      centro(new_center)
    })
    
    # Reset map markers and view
    observeEvent(input$reset_mapa, {
      negocios_data(data.frame()) # Clear business data
      user_location(NULL) # Clear user location
      # Reset to default center from APP_CONFIG
      centro(c(lat = APP_CONFIG$default_lat, lng = APP_CONFIG$default_lng))
      leafletProxy("mapa") %>%
        clearGroup("markers") %>%
        setView(lng = APP_CONFIG$default_lng, lat = APP_CONFIG$default_lat, zoom = 13) # Use APP_CONFIG
    })
    
    
    # Search for businesses
    observeEvent(input$buscar, {
      req(centro()) # Ensure map center is available
      
      tryCatch({
        lat <- centro()[1]
        lon <- centro()[2]
        
        # Check for INEGI API key
        if (!nzchar(Sys.getenv("INEGI_API_KEY"))) {
          # Use simulated data if API key is missing
          n_negocios <- sample(5:15, 1)
          negocios_sim <- data.frame(
            nombre = paste("Negocio Simulado", 1:n_negocios),
            latitud = lat + runif(n_negocios, -0.005, 0.005),
            longitud = lon + runif(n_negocios, -0.005, 0.005),
            stringsAsFactors = FALSE
          )
          negocios_data(negocios_sim)
          showNotification(
            paste("Se encontraron", n_negocios, "negocios (simulados por falta de API key)."),
            type = "warning"
          )
        } else {
          # Use real API data
          tipos <- trimws(unlist(strsplit(input$palabra_clave, ",")))
          negocios_todos <- data.frame()
          
          for (tipo_kw in tipos) {
            negocios_tipo <- inegi_denue(
              latitud = lat,
              longitud = lon,
              meters = input$radio,
              keyword = tipo_kw
            )
            if (nrow(negocios_tipo) > 0) {
              negocios_todos <- rbind(negocios_todos, negocios_tipo)
            }
          }
          
          negocios_todos <- unique(negocios_todos) # Remove duplicates
          negocios_data(negocios_todos)
          
          if (nrow(negocios_todos) == 0) {
            showNotification("No se encontraron negocios cercanos.", type = "warning")
          } else {
            showNotification(
              paste("Se encontraron", nrow(negocios_todos), "negocios."),
              type = "message"
            )
          }
        }
      }, error = function(e) {
        showNotification(paste("Error al buscar negocios:", e$message), type = "error")
        message("Error en observeEvent input$buscar: ", e$message) # Log to console
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
          label = ~ paste0(
            "<b>ID Hex: ", id_hex, "</b><br>",
            "Población Total: ", poblacion_total, "<br>",
            input$variable, ": ", round(variable_data, 2)
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
