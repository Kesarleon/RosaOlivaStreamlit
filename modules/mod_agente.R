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
        tableOutput(ns("tabla_comparacion"))
      ),
      column(
        width = 6,
        h4("Variables más importantes del modelo"),
        plotOutput(ns("grafico_importancia")),
        h4("Resumen estadístico de AGEBS similares"),
        tableOutput(ns("tabla_stats"))
      )
    )
  )
}

mod_agente_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # AGEBS simuladas con variables socioeconómicas
    ag_data <- reactive({
      n <- 100
      data.frame(
        id = paste0("AGEB_", 1:n),
        lng = runif(n, -96.75, -96.70),
        lat = runif(n, 17.05, 17.10),
        ingreso = rnorm(n, 7500, 1500),
        escolaridad = rnorm(n, 9, 2),
        mujeres = sample(200:1000, n, replace = TRUE),
        cap_rosa = runif(n, 0.2, 0.9),
        cap_comp = runif(n, 0.1, 0.7)
      )
    })
    
    ag_sf <- reactive({
      st_as_sf(ag_data(), coords = c("lng", "lat"), crs = 4326)
    })
    
    nueva_ubicacion <- reactiveVal(NULL)
    
    observeEvent(input$marcar_nueva, {
      showModal(modalDialog("Haz clic en el mapa para colocar nueva ubicación.", easyClose = TRUE))
    })
    
    observeEvent(input$mapa_agente_click, {
      click <- input$mapa_agente_click
      nueva_ubicacion(c(lng = click$lng, lat = click$lat))
    })
    
    output$mapa_agente <- renderLeaflet({
      pal <- colorNumeric("YlOrBr", domain = ag_data()$cap_rosa)
      map <- leaflet() %>%
        addProviderTiles("CartoDB.Positron") %>%
        addCircleMarkers(data = ag_sf(),
                         color = ~pal(cap_rosa), radius = 5,
                         label = ~id, stroke = TRUE, fillOpacity = 0.8)
      if (!is.null(nueva_ubicacion())) {
        map <- map %>%
          addMarkers(lng = nueva_ubicacion()["lng"],
                     lat = nueva_ubicacion()["lat"],
                     icon = list(
                       iconUrl = "www/marker_rosa.png",
                       iconWidth = 30, iconHeight = 30
                     ))
      }
      map
    })
    
    output$tabla_stats <- renderTable({
      df <- ag_data()
      df_similares <- df[df$cap_rosa > 0.7, ]
      stats <- summarise_all(df_similares[, c("ingreso", "escolaridad", "mujeres")], 
                             list(media = mean, sd = sd))
      t(stats)
    }, rownames = TRUE)
    
    output$grafico_importancia <- renderPlot({
      var_importancia <- data.frame(
        variable = c("Ingreso", "Escolaridad", "Mujeres"),
        importancia = c(0.45, 0.35, 0.20)
      )
      barplot(var_importancia$importancia,
              names.arg = var_importancia$variable,
              col = "darkolivegreen4",
              main = "Importancia de variables en el modelo")
    })
    
    output$tabla_comparacion <- renderTable({
      if (is.null(nueva_ubicacion())) return(NULL)
      # Simulación de comparación
      data.frame(
        Métrica = c("Captación Rosa Oliva", "Captación competencia"),
        Estimación = c(round(runif(1, 0.4, 0.8), 2), round(runif(1, 0.1, 0.6), 2))
      )
    })
  })
}
