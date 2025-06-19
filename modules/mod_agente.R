# Módulo agente de expansión con modelo ML y simulación de nueva sucursal

# modules/mod_agente.R

mod_agente_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        width = 6,
        leafletOutput(ns("mapa_agente"), height = 500),
        actionButton(ns("marcar_nueva"), "Agregar nueva ubicación"),
        br(), br(),
        # This table would show a comparison if a new location is marked
        tableOutput(ns("tabla_comparacion"))
      ),
      column(
        width = 6,
        h4("Variables más importantes del modelo (Simulado)"),
        plotOutput(ns("grafico_importancia")),
        h4("Resumen estadístico de AGEBS similares (Simulado)"),
        tableOutput(ns("tabla_stats"))
      )
    )
  )
}

mod_agente_server <- function(id) {
  # ---
  # Current Data Source: Simulated Data
  # The `ag_data` reactiveVal below generates SIMULATED AGEB data along with
  # simulated socio-economic variables and mock capture potentials (`cap_rosa`, `cap_comp`).
  # This is for demonstration of the module's functionality.
  #
  # Potential Integration with Real Data & ML Model:
  # For a production version, `ag_data` could be:
  #  1. Derived from `agebs_hex` (loaded in `global.R`): This would involve
  #     taking the real hexagonal grid data, potentially filtering it for relevant
  #     areas, or augmenting it with additional data if necessary.
  #  2. The result of a more sophisticated Machine Learning (ML) model:
  #     - Input: Characteristics from `agebs_hex` (population density, specific customer profiles, etc.).
  #     - Output: Predicted variables like `cap_rosa` (capture potential for Rosa Oliva)
  #               and `cap_comp` (capture potential for competitors).
  #     This ML model would need to be trained separately and then applied here to the
  #     `agebs_hex` data to generate the necessary inputs for this module's analysis.
  #  3. The "Variables más importantes" and "Resumen estadístico" would then reflect
  #     the actual data and model used, rather than the current simulated placeholders.
  # ---
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Simulated AGEB data with socio-economic and capture potential variables
    ag_data <- reactive({
      n <- 100 # Number of simulated AGEBs/points
      data.frame(
        id = paste0("AGEB_SIM_", 1:n),
        lng = runif(n, -96.75, -96.70), # Coordinates around Oaxaca
        lat = runif(n, 17.05, 17.10),
        ingreso = rnorm(n, 7500, 1500),     # Simulated mean income
        escolaridad = rnorm(n, 9, 2),       # Simulated mean education years
        mujeres = sample(200:1000, n, replace = TRUE), # Simulated female population
        cap_rosa = runif(n, 0.2, 0.9),     # Simulated capture potential for Rosa Oliva
        cap_comp = runif(n, 0.1, 0.7)      # Simulated capture potential for competitors
      )
    })
    
    # Convert reactive data to sf object for mapping
    ag_sf <- reactive({
      st_as_sf(ag_data(), coords = c("lng", "lat"), crs = 4326) # WGS84
    })
    
    nueva_ubicacion <- reactiveVal(NULL) # Stores coordinates of a potential new location
    
    observeEvent(input$marcar_nueva, {
      showModal(modalDialog("Haz clic en el mapa para colocar una nueva ubicación.", easyClose = TRUE))
    })
    
    # Capture map click for new location
    observeEvent(input$mapa_agente_click, {
      click <- input$mapa_agente_click
      if (!is.null(click)) {
        nueva_ubicacion(c(lng = click$lng, lat = click$lat))
        removeModal() # Close the instruction modal
      }
    })
    
    output$mapa_agente <- renderLeaflet({
      pal <- colorNumeric("YlOrBr", domain = ag_data()$cap_rosa, na.color = "transparent")
      map <- leaflet() %>%
        addProviderTiles("CartoDB.Positron") %>%
        setView(lng = APP_CONFIG$default_lng, lat = APP_CONFIG$default_lat, zoom = 12) %>% # Use default center
        addCircleMarkers(
          data = ag_sf(),
          color = ~pal(cap_rosa),
          radius = 5, # Consider scaling radius by a variable if appropriate
          label = ~id,
          stroke = TRUE,
          fillOpacity = 0.8,
          popup = ~paste0("<b>ID:</b> ", id, "<br>",
                         "<b>Potencial Rosa Oliva:</b> ", round(cap_rosa, 2), "<br>",
                         "<b>Potencial Competencia:</b> ", round(cap_comp, 2))
        ) %>%
        addLegend(pal = pal, values = ag_data()$cap_rosa, opacity = 0.7, title = "Potencial Captura R.O.",
                  position = "bottomright")

      if (!is.null(nueva_ubicacion())) {
        map <- map %>%
          addMarkers(
            lng = nueva_ubicacion()["lng"],
            lat = nueva_ubicacion()["lat"],
            icon = list(iconUrl = "www/marker_rosa.png", iconWidth = 30, iconHeight = 30), # Ensure marker exists
            popup = "Nueva Ubicación Propuesta"
          )
      }
      map
    })
    
    # This output reflects the simulated data and a hypothetical model.
    # If using real data and a trained ML model, this table would show actual summary statistics
    # of AGEBs that are deemed "similar" to a target area, based on the model's criteria or clustering.
    output$tabla_stats <- renderTable({
      df <- ag_data()
      # Example: Show stats for AGEBs with high Rosa Oliva capture potential (simulated)
      df_similares <- df[df$cap_rosa > 0.7, ]
      if (nrow(df_similares) == 0) return(data.frame(Mensaje = "No hay AGEBs simulados con alta similitud."))

      stats <- df_similares %>%
        select(ingreso, escolaridad, mujeres) %>%
        summarise_all(list(media = ~mean(., na.rm = TRUE), sd = ~sd(., na.rm = TRUE)))

      # Transpose for better readability
      t(stats)
    }, rownames = TRUE, caption = "Estadísticas de AGEBs Simulados Similares (cap_rosa > 0.7)",
       caption.placement = getOption("xtable.caption.placement", "top"))
    
    # This plot represents SHAP values or similar feature importance from a hypothetical ML model.
    # In a real scenario, this would be generated from the actual trained model.
    output$grafico_importancia <- renderPlot({
      # Simulated feature importance
      var_importancia <- data.frame(
        variable = c("Ingreso Promedio", "Nivel de Escolaridad", "Densidad Poblacional Mujeres", "Cercanía a Competencia (-)"),
        importancia = c(0.45, 0.35, 0.20, 0.15) # Example values
      )
      var_importancia <- var_importancia[order(var_importancia$importancia, decreasing = TRUE),]

      barplot(height = var_importancia$importancia,
              names.arg = var_importancia$variable,
              col = "darkolivegreen4",
              main = "Importancia de Variables (Modelo Simulado)",
              ylab = "Importancia Relativa",
              las = 2) # Rotate x-axis labels for readability
    })
    
    # This table would compare key metrics for the proposed new location against averages or benchmarks.
    # Currently, it's a placeholder with random values.
    output$tabla_comparacion <- renderTable({
      if (is.null(nueva_ubicacion())) return(NULL) # Show only if a new location is marked
      # Simulation of comparison metrics for the new location
      data.frame(
        Métrica = c("Potencial Captación Estimado (Rosa Oliva)", "Potencial Captación Competencia Cercana", "Canibalización Estimada (Otras Sucursales R.O.)"),
        Estimación_Nueva_Ubicación = c(round(runif(1, 0.4, 0.8), 2), round(runif(1, 0.1, 0.6), 2), round(runif(1, 0.05, 0.15),2)),
        Benchmark_Area_Similar = c(0.55, 0.30, 0.10) # Example benchmark values
      )
    }, caption = "Análisis Comparativo de Nueva Ubicación (Simulado)",
       caption.placement = getOption("xtable.caption.placement", "top"))
  })
}
