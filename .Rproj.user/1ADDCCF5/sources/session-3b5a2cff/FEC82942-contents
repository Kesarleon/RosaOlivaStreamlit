# Módulo Mapa con hexbin, ubicación, búsqueda DENUE y socioeconómico

# modules/mod_mapa.R

mod_mapa_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        width = 8,
        leafletOutput(ns("mapa"), height = "700px"),
        br(),
        actionButton("get_location", "Obtener mi ubicación"),
        wellPanel(
          textInput(ns("estado"), "Estado:", "Oaxaca"),
          textInput(ns("municipio"), "Municipio:", ""),
          textInput(ns("localidad"), "Localidad:", ""),
          actionButton(ns("centrar"), "Centrar mapa"),
          hr(),
          textInput(ns("palabra_clave"), "Palabra clave (ej. joyería, boutique):", "tienda, farmacia"),
          numericInput(ns("radio"), "Radio de búsqueda (m):", 1000, min = 100, step = 100),
          actionButton(ns("buscar"), "Buscar negocios"),
          tags$script(HTML(
            "Shiny.addCustomMessageHandler('get_location', function(message) {
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
          function(position) {
            Shiny.setInputValue('location', {
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
          ))
        )
      ),
      column(
        width = 4,
        selectInput(
          ns("variable"),
          "Perfil del cliente:",
          choices = c("Emprendedor Joven Digital" = "poblacion", "Mamá Emprendedora" = "ingreso", "Mayorista Experimentado" = "escolaridad"),
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
    
    observeEvent(input$get_location, {
      session$sendCustomMessage("get_location", list())
    })
    
    # Ubicación inicial: Oaxaca centro
    centro <- reactiveVal(c(lat = 17.0594, lng = -96.7216))
    
    observeEvent(input$centrar, {
      # Aquí podrías usar geocodificación real (comentado):
      # resultado <- google_geocode(paste(input$localidad, input$municipio, input$estado), key = token_google)
      # if (length(resultado$results) > 0) {
      #   loc <- resultado$results$geometry$location
      #   centro(c(lat = loc$lat, lng = loc$lng))
      # }
      
      # Simulación: mover centro un poco aleatoriamente
      #centro(c(lat = centro()[1] + runif(1, -0.01, 0.01), lng = centro()[2] + runif(1, -0.01, 0.01)))
    })
    
    observeEvent(input$location, {
      user_location(input$location)
    })
    
    # Localizacion del usuario y negocios cercanos
    update_map <- function() {
      if (!is.null(user_location())) {
        lat <- user_location()$lat
        lon <- user_location()$lon
        tipos <- str_trim(unlist(strsplit(input$palabra_clave, ",")))
        token <- "3169f103-2c0b-4882-b817-d26a276b16c6"
        meters <- input$radio
        

        negocios_todos <- do.call(rbind, lapply(tipos, function(t) {
          inegi_denue(lat, lon, token, meters = meters, keyword = t)
        }))
        
        negocios_todos <- unique(negocios_todos)
        
        if (nrow(negocios_todos) == 0) {
          showNotification("No se encontraron negocios cercanos.", type = "warning")
        }
        
 #       output$mapa <- renderLeaflet({
 #         mapa <- leaflet() %>%
 #           addTiles() %>%
 #           setView(lng = lon, lat = lat, zoom = 15) %>%
 #           addAwesomeMarkers(lng = lon, lat = lat, popup = "¡Aquí estás tú!", icon = awesomeIcons(icon = 'user', markerColor = 'green'))
 #         
 #         if (nrow(negocios_todos) > 0) {
 #           popup_info <- paste0("<b>", negocios_todos$nombre, "</b>")
 #           
 #           mapa <- mapa %>%
 #             addMarkers(
 #               lng = as.numeric(negocios_todos$longitud),
 #               lat = as.numeric(negocios_todos$latitud),
 #               popup = popup_info
 #             )
 #         }
 #         mapa
 #       })
        
        return(negocios_todos)
      }
    }
    
    observeEvent(user_location(), {
      update_map()
    })
    
    negocios_encontrados <- eventReactive(input$buscar, {
      update_map()
    })
#    negocios_encontrados <- eventReactive(input$buscar, {
#      inegi_denue(centro()[1], centro()[2], input$palabra_clave, input$radio)
#    })
    
    output$mapa <- renderLeaflet({
      leaflet() |>
        addProviderTiles("CartoDB.Positron") |>
        setView(lng = centro()[2], lat = centro()[1], zoom = 13) |>
        addPolygons(data = agebs_hex, fillColor = "transparent", color = "gray", weight = 1, label = ~poblacion)
    })
    
    observe({
      req(input$variable)
      leafletProxy("mapa") |>
        clearGroup("hex") |>
        addPolygons(
          data = agebs_hex,
          fillColor = ~colorNumeric("YlGn", agebs_hex[[input$variable]])(agebs_hex[[input$variable]]),
          fillOpacity = 0.6,
          color = "white",
          weight = 1,
          label = ~paste(poblacion, "<br>", input$variable, ": ", agebs_hex[[input$variable]]),
          group = "hex"
        )
    })
    
    #       output$mapa <- renderLeaflet({
    #         mapa <- leaflet() %>%
    #           addTiles() %>%
    #           setView(lng = lon, lat = lat, zoom = 15) %>%
    #           addAwesomeMarkers(lng = lon, lat = lat, popup = "¡Aquí estás tú!", icon = awesomeIcons(icon = 'user', markerColor = 'green'))
    #         
    #         if (nrow(negocios_todos) > 0) {
    #           popup_info <- paste0("<b>", negocios_todos$nombre, "</b>")
    #           
    #           mapa <- mapa %>%
    #             addMarkers(
    #               lng = as.numeric(negocios_todos$longitud),
    #               lat = as.numeric(negocios_todos$latitud),
    #               popup = popup_info
  
    
    observeEvent(update_map(), {
      leafletProxy("mapa") |>
        clearGroup("negocios") |>
        addMarkers(
          lng = as.numeric(negocios_encontrados$longitud),
          lat = as.numeric(negocios_encontrados$latitud),
          label = negocios_encontrados$Nombre,
          group = "negocios",
          icon = list(
            iconUrl = "www/icono_marcador.png",
            iconWidth = 30, iconHeight = 30
          )
        ) %>% 
      addAwesomeMarkers(lng = user_location()$lon, 
                        lat = user_location()$lat, 
                        popup = "¡Aquí estás tú!", 
                        icon = awesomeIcons(icon = 'user', 
                                            markerColor = 'green')
                        )
    })
    
    output$histograma <- renderPlot({
      var <- input$variable
      hist(agebs_hex[[var]], breaks = 20, col = "#7A9E7E", border = "white",
           main = paste("Distribución de Perfil"), xlab = '')#, var)), xlab = var)
    })
  })
}
