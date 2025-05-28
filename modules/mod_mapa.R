mod_mapa_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        width = 8,
        leafletOutput(ns("mapa"), height = "700px"),
        br(),
        actionButton(ns("get_location"), "Obtener mi ubicación"),
        wellPanel(
          textInput(ns("estado"), "Estado:", "Oaxaca"),
          textInput(ns("municipio"), "Municipio:", ""),
          textInput(ns("localidad"), "Localidad:", ""),
          actionButton(ns("centrar"), "Centrar mapa"),
          hr(),
          textInput(ns("palabra_clave"), "Palabra clave (ej. joyería, farmacia):", ""),
          numericInput(ns("radio"), "Radio de búsqueda (m):", 1000, min = 100, step = 100),
          actionButton(ns("buscar"), "Buscar negocios")
        ),
        tags$script(HTML("
          Shiny.addCustomMessageHandler('get_location', function(message) {
            if (navigator.geolocation) {
              navigator.geolocation.getCurrentPosition(
                function(position) {
                  Shiny.setInputValue('ubicacion_usuario', {
                    lat: position.coords.latitude,
                    lon: position.coords.longitude
                  });
                },
                function() {
                  alert('No se pudo obtener la ubicación.');
                }
              );
            } else {
              alert('La geolocalización no es soportada por este navegador.');
            }
          });
        "))
      ),
      column(
        width = 4,
        selectInput(
          ns("variable"),
          "Variable socioeconómica:",
          choices = c("Población" = "poblacion", "Ingreso" = "ingreso", "Escolaridad" = "escolaridad"),
          selected = "poblacion"
        ),
        plotOutput(ns("histograma"))
      )
    )
  )
}

mod_mapa_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    user_location <- reactiveVal(NULL)
    centro <- reactiveVal(c(lat = 17.0594, lng = -96.7216))
    
    observeEvent(input$get_location, {
      session$sendCustomMessage("get_location", list())
    })
    
    observeEvent(input$ubicacion_usuario, {
      coords <- input$ubicacion_usuario
      user_location(coords)
      centro(c(lat = coords$lat, lng = coords$lon))
    })
    
    observeEvent(input$centrar, {
      # Simulación de geocodificación
      centro(c(lat = 17.06 + runif(1, -0.01, 0.01), lng = -96.72 + runif(1, -0.01, 0.01)))
    })
    
    negocios <- reactiveVal(NULL)
    
    observeEvent(input$buscar, {
      loc <- centro()
      keywords <- str_trim(unlist(strsplit(input$palabra_clave, ",")))
      token <- "3169f103-2c0b-4882-b817-d26a276b16c6"
      radius <- input$radio
      
      results <- do.call(rbind, lapply(keywords, function(k) {
        inegi_denue(loc$lat, loc$lng, token, meters = radius, keyword = k)
      }))
      
      if (nrow(results) == 0) {
        showNotification("No se encontraron negocios cercanos", type = "warning")
      }
      
      negocios(results)
    })
    
    output$mapa <- renderLeaflet({
      leaflet() %>%
        addProviderTiles("CartoDB.Positron") %>%
        setView(lng = centro()$lng, lat = centro()$lat, zoom = 13)
    })
    
    observe({
      req(input$variable)
      leafletProxy("mapa") %>%
        clearGroup("hex") %>%
        addPolygons(
          data = agebs_hex,
          fillColor = ~colorNumeric("YlGn", agebs_hex[[input$variable]])(agebs_hex[[input$variable]]),
          fillOpacity = 0.6,
          color = "white",
          weight = 1,
          label = ~paste("AGEB", "<br>", input$variable, ": ", round(agebs_hex[[input$variable]], 1)),
          group = "hex"
        )
    })
    
    observeEvent(negocios(), {
      req(negocios())
      leafletProxy("mapa") %>%
        clearGroup("negocios") %>%
        addMarkers(
          lng = as.numeric(negocios()$longitud),
          lat = as.numeric(negocios()$latitud),
          popup = negocios()$nombre,
          group = "negocios",
          icon = icons(
            iconUrl = "www/marker_icon.png",
            iconWidth = 30, iconHeight = 30
          )
        )
    })
    
    observe({
      req(user_location())
      leafletProxy("mapa") %>%
        addAwesomeMarkers(
          lng = user_location()$lon,
          lat = user_location()$lat,
          icon = awesomeIcons(icon = 'user', markerColor = 'green'),
          popup = "¡Aquí estás tú!"
        )
    })
    
    output$histograma <- renderPlot({
      var <- input$variable
      hist(agebs_hex[[var]], breaks = 15, col = "#7A9E7E", border = "white",
           main = paste("Distribución de", var), xlab = var)
    })
  })
}
