# Módulo para visualización de histogramas socioeconómicos

# modules/mod_socio.R

mod_socio_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        width = 4,
        # Consider making "Oaxaca" a configurable default if it can change
        textInput(ns("centro"), "Centro del mapa (Estado/Municipio/Localidad):", "Oaxaca"),
        actionButton(ns("centrar"), "Centrar"),
        textInput(ns("palabras"), "Palabras clave (negocios):",
                  value = APP_CONFIG$socio_search_keyword_default), # From APP_CONFIG
        numericInput(ns("radio"), "Radio de búsqueda (m):",
                     value = APP_CONFIG$map_search_radius_default, # From APP_CONFIG (shared with mod_mapa)
                     min = 100),
        actionButton(ns("buscar_negocios"), "Buscar negocios"),
        # The choices for 'variable' are currently based on simulated data in mod_socio_server.
        # If integrated with `agebs_hex` from global.R, these choices would need to be updated
        # to reflect available columns in `agebs_hex` (e.g., "poblacion_total", "joven_digital").
        selectInput(ns("variable"), "Variable socioeconómica:",
                    choices = c("Ingreso", "Escolaridad", "Hogares", "Población femenina")),
        br(), br(),
        leafletOutput(ns("mapa_socio"), height = "500px") # Consistent height unit
      ),
      column(
        width = 8,
        plotOutput(ns("histograma"))
      )
    )
  )
}

mod_socio_server <- function(id) {
  # ---
  # Current Data Source: Simulated Data
  # The `hexbin_socio` reactiveVal below generates and uses SIMULATED socio-economic data
  # for demonstration purposes. This allows the module to function independently.
  #
  # Potential Integration with Real Data (`agebs_hex` from global.R):
  # To use the main application data, this module would need to:
  #  1. Accept `agebs_hex` as a reactive input parameter, for example:
  #     `mod_socio_server <- function(id, agebs_data_reactive)`
  #     Then, `agebs_data_reactive()` would be used instead of `hexbin_socio()`.
  #  2. Adapt internal logic to use columns from `agebs_hex` (e.g., `poblacion_total`,
  #     `joven_digital`, `mama_emprendedora`, `mayorista_experimentado`, `clientes_totales`).
  #     The `selectInput(ns("variable"), ...)` choices in the UI would also need to be updated.
  #  3. The map rendering might need adjustment: instead of `addCircleMarkers` based on
  #     simulated points, it would use `addPolygons` with the `geometry` column from `agebs_hex`,
  #     similar to how `mod_mapa.R` displays hexbins.
  # ---
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    hexbin_socio <- reactiveVal({
      # Simulación de 50 puntos (representando hexágonos o centroides de AGEBs)
      # con variables socioeconómicas específicas para este módulo.
      coords <- data.frame(
        lng = runif(50, -96.75, -96.70),
        lat = runif(50, 17.05, 17.10),
        ingreso = rnorm(50, 8000, 2000),
        escolaridad = rnorm(50, 10, 2),
        hogares = sample(100:500, 50, replace = TRUE),
        poblacion_femenina = sample(200:1000, 50, replace = TRUE)
      )
      sf::st_as_sf(coords, coords = c("lng", "lat"), crs = 4326) # WGS84
    })
    
    # Initialize map center from APP_CONFIG
    centro_coords <- reactiveVal(c(lng = APP_CONFIG$default_lng, lat = APP_CONFIG$default_lat))
    
    observeEvent(input$centrar, {
      centro_coords(
        c(
          lng = APP_CONFIG$default_lng + runif(1, -0.02, 0.02),
          lat = APP_CONFIG$default_lat + runif(1, -0.02, 0.02)
        )
      )
      leafletProxy("mapa_socio") %>%
        setView(lng = centro_coords()["lng"], lat = centro_coords()["lat"], zoom = 13)
    })
    
    observeEvent(input$buscar_negocios, {
      showModal(
        modalDialog(
          title = "Búsqueda Simulada",
          paste(
            "Simulando búsqueda de:", input$palabras,
            "en un radio de", input$radio, "m alrededor de",
            round(centro_coords()["lat"], 4), ",", round(centro_coords()["lng"], 4)
          ),
          easyClose = TRUE,
          footer = NULL
        )
      )
    })
    
    output$mapa_socio <- renderLeaflet({
      current_hex_data <- hexbin_socio()
      variable_seleccionada <- tolower(input$variable)
      if (!variable_seleccionada %in% names(current_hex_data)) {
        shiny::showNotification(paste("Variable", input$variable, "no encontrada en datos simulados."), type = "error")
        return(leaflet() %>% addTiles() %>% setView(lng = APP_CONFIG$default_lng, lat = APP_CONFIG$default_lat, zoom = 12))
      }

      pal <- colorNumeric("YlGn", domain = current_hex_data[[variable_seleccionada]], na.color = "transparent")

      leaflet(current_hex_data) %>%
        addProviderTiles("CartoDB.Positron") %>%
        setView(lng = centro_coords()["lng"], lat = centro_coords()["lat"], zoom = 12) %>%
        addCircleMarkers( # Using circle markers for the simulated point data
          radius = 6,
          color = ~ pal(get(variable_seleccionada)),
          stroke = TRUE,
          fillOpacity = 0.7,
          popup = ~ paste0(
            "<b>Variable: ", Hmisc::capitalize(variable_seleccionada), "</b><br>",
            "Valor: ", round(get(variable_seleccionada), 2)
          )
        ) %>%
        addMarkers(
          lng = centro_coords()["lng"],
          lat = centro_coords()["lat"],
          icon = list(iconUrl = "www/marker_rosa.png", iconWidth = 30, iconHeight = 30),
          popup = "Centro de búsqueda"
        ) %>%
        addLegend(pal = pal, values = ~get(variable_seleccionada), opacity = 0.7, title = input$variable,
                  position = "bottomright")
    })
    
    output$histograma <- renderPlot({
      current_hex_data <- hexbin_socio()
      variable_seleccionada <- tolower(input$variable)

      if (!variable_seleccionada %in% names(current_hex_data) || !is.numeric(current_hex_data[[variable_seleccionada]])) {
        plot(0, 0, type = "n", xlab = "", ylab = "", main = "Datos no disponibles o no numéricos para el histograma.")
        return()
      }

      hist_data <- current_hex_data[[variable_seleccionada]]
      hist(
        hist_data,
        main = paste("Distribución de", Hmisc::capitalize(input$variable)),
        xlab = Hmisc::capitalize(input$variable),
        ylab = "Frecuencia de Puntos Simulados", # Changed from Hexágonos
        col = "darkolivegreen3",
        border = "white"
      )
    })
  })
}
