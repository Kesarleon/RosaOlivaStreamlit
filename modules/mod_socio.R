# Módulo para visualización de histogramas socioeconómicos

# modules/mod_socio.R

mod_socio_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        width = 4,
        textInput(ns("centro"), "Centro del mapa (Estado/Municipio/Localidad):", "Oaxaca"),
        actionButton(ns("centrar"), "Centrar"),
        textInput(ns("palabras"), "Palabras clave (negocios):", "joyería"),
        numericInput(ns("radio"), "Radio de búsqueda (m):", 1000, min = 100),
        actionButton(ns("buscar_negocios"), "Buscar negocios"),
        selectInput(ns("variable"), "Variable socioeconómica:", 
                    choices = c("Ingreso", "Escolaridad", "Hogares", "Población femenina")),
        br(), br(),
        leafletOutput(ns("mapa_socio"), height = 500)
      ),
      column(
        width = 8,
        plotOutput(ns("histograma"))
      )
    )
  )
}

mod_socio_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Hexágonos simulados
    hexbin <- reactiveVal({
      # Simulación de 50 hexágonos
      coords <- data.frame(
        lng = runif(50, -96.75, -96.70),
        lat = runif(50, 17.05, 17.10),
        ingreso = rnorm(50, 8000, 2000),
        escolaridad = rnorm(50, 10, 2),
        hogares = sample(100:500, 50, replace = TRUE),
        mujeres = sample(200:1000, 50, replace = TRUE)
      )
      sf::st_as_sf(coords, coords = c("lng", "lat"), crs = 4326)
    })
    
    centro_coords <- reactiveVal(c(lng = -96.72, lat = 17.07))
    
    observeEvent(input$centrar, {
      # Simular geocodificación
      centro_coords(c(lng = runif(1, -96.74, -96.70), lat = runif(1, 17.05, 17.10)))
    })
    
    observeEvent(input$buscar_negocios, {
      showModal(modalDialog("Simulando búsqueda con inegi_denue...", easyClose = TRUE))
      # En producción: usar función real inegi_denue(input$palabras, input$radio, coords)
    })
    
    output$mapa_socio <- renderLeaflet({
      pal <- colorNumeric("YlGn", domain = hexbin()[[tolower(input$variable)]])
      leaflet(hexbin()) %>%
        addProviderTiles("CartoDB.Positron") %>%
        addCircleMarkers(radius = 6, color = ~pal(get(tolower(input$variable))),
                         stroke = TRUE, fillOpacity = 0.7) %>%
        addMarkers(lng = centro_coords()["lng"], lat = centro_coords()["lat"],
                   icon = list(
                     iconUrl = "www/marker_rosa.png", 
                     iconWidth = 30, iconHeight = 30
                   ))
    })
    
    output$histograma <- renderPlot({
      var <- tolower(input$variable)
      hist(hexbin()[[var]], main = paste("Distribución de", input$variable),
           xlab = input$variable, col = "darkolivegreen3", border = "white")
    })
  })
}
