# Módulo Mapa con hexbin, ubicación, búsqueda DENUE y socioeconómico

mod_mapa_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        width = 8,
        leafletOutput(ns("mapa"), height = "700px"),
        br(),
        actionButton(ns("get_location"), "Obtener mi ubicación"),
        actionButton(ns("reset_mapa"), "Borrar marcadores y centrar mapa"),
        checkboxInput(ns("mostrar_hexbin"), "Mostrar hexágonos", value = TRUE),
        wellPanel(
          textInput(ns("estado"), "Estado:", "Oaxaca"),
          textInput(ns("municipio"), "Municipio:", ""),
          textInput(ns("localidad"), "Localidad:", ""),
          actionButton(ns("centrar"), "Centrar mapa"),
          hr(),
          textInput(ns("palabra_clave"), "Palabra clave (ej. joyería, boutique):", "joyería"),
          numericInput(ns("radio"), "Radio de búsqueda (m):", 1000, min = 100, step = 100),
          actionButton(ns("buscar"), "Buscar negocios"),
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
          )))
        )
      ),
      column(
        width = 4,
        selectInput(
          ns("variable"),
          "Perfil del cliente:",
          choices = c(
            "Emprendedor Joven Digital" = "poblacion", 
            "Mamá Emprendedora" = "ingreso", 
            "Mayorista Experimentado" = "escolaridad"
          ),
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
    
    # Variables reactivas
    user_location <- reactiveVal(NULL)
    centro <- reactiveVal(c(lat = 17.0594, lng = -96.7216))
    negocios_data <- reactiveVal(data.frame())
    
    # Manejar geolocalización
    observeEvent(input$get_location, {
      session$sendCustomMessage(paste0("get_location_", id), list())
    })
    
    observeEvent(input$location, {
      if (!is.null(input$location)) {
        user_location(input$location)
        centro(c(lat = input$location$lat, lng = input$location$lon))
      }
    })
    
    # Centrar mapa
    observeEvent(input$centrar, {
      # Simulación de geocodificación
      new_center <- c(
        lat = centro()[1] + runif(1, -0.01, 0.01), 
        lng = centro()[2] + runif(1, -0.01, 0.01)
      )
      centro(new_center)
    })
    
    observeEvent(input$reset_mapa, {
      negocios_data(data.frame())
      user_location(NULL)
      centro(c(lat = 17.0594, lng = -96.7216))
      leafletProxy("mapa") %>%
        clearGroup("markers") %>%
        setView(lng =  -96.7216, lat = 17.0594, zoom = 13)
    })
    
    
    # Buscar negocios
    observeEvent(input$buscar, {
      req(centro())
      
      tryCatch({
        lat <- centro()[1]
        lon <- centro()[2]
        
        # Verificar si tenemos token INEGI
        if (Sys.getenv("INEGI_API_KEY") == "") {
          # Datos simulados
          n_negocios <- sample(5:15, 1)
          negocios_sim <- data.frame(
            nombre = paste("Negocio", 1:n_negocios),
            latitud = lat + runif(n_negocios, -0.005, 0.005),
            longitud = lon + runif(n_negocios, -0.005, 0.005),
            stringsAsFactors = FALSE
          )
          negocios_data(negocios_sim)
          showNotification(paste("Se encontraron", n_negocios, "negocios (simulados)"), type = "message")
        } else {
          # Usar API real
          tipos <- trimws(unlist(strsplit(input$palabra_clave, ",")))
          negocios_todos <- data.frame()
          
          for (tipo in tipos) {
            negocios_tipo <- inegi_denue(lat, lon, meters = input$radio, keyword = tipo)
            if (nrow(negocios_tipo) > 0) {
              negocios_todos <- rbind(negocios_todos, negocios_tipo)
            }
          }
          
          negocios_todos <- unique(negocios_todos)
          negocios_data(negocios_todos)
          
          if (nrow(negocios_todos) == 0) {
            showNotification("No se encontraron negocios cercanos.", type = "warning")
          } else {
            showNotification(paste("Se encontraron", nrow(negocios_todos), "negocios"), type = "message")
          }
        }
      }, error = function(e) {
        showNotification(paste("Error al buscar negocios:", e$message), type = "error")
      })
    })
    
    # Renderizar mapa base
    output$mapa <- renderLeaflet({
      leaflet() %>%
        addProviderTiles("CartoDB.Positron") %>%
        setView(lng = centro()[2], lat = centro()[1], zoom = 13)
    })
    
    observe({
      req(input$mostrar_hexbin)
      req(input$variable)
      req(agebs_hex)
      
      variable_data <- agebs_hex[[input$variable]]
      if (all(is.na(variable_data))) {
        variable_data <- rep(1, nrow(agebs_hex))
      }
      
      pal <- colorNumeric("YlGn", domain = variable_data, na.color = "transparent")
      
      leafletProxy("mapa") %>%
        clearGroup("hex") %>%
        addPolygons(
          data = agebs_hex,
          fillColor = ~pal(variable_data),
          fillOpacity = 0.6,
          color = "white",
          weight = 1,
          label = ~paste0("Población: ", poblacion, "<br>", 
                          input$variable, ": ", round(variable_data, 2)),
          group = "hex"
        )
    })
    
    observe({
      if (!input$mostrar_hexbin) {
        leafletProxy("mapa") %>% clearGroup("hex")
      }
    })
    
    
    # Actualizar marcadores de negocios y ubicación
    observe({
      proxy <- leafletProxy("mapa")
      
      # Limpiar marcadores existentes
      proxy %>% clearGroup("markers")
      
      # Agregar ubicación del usuario
      if (!is.null(user_location())) {
        proxy %>%
          addAwesomeMarkers(
            lng = user_location()$lon, 
            lat = user_location()$lat, 
            popup = "¡Aquí estás tú!", 
            icon = awesomeIcons(icon = 'user', markerColor = 'green'),
            group = "markers"
          )
      }
      
      # Agregar negocios
      if (nrow(negocios_data()) > 0) {
        negocios <- negocios_data()
        
        # Verificar nombres de columnas
        lat_col <- if("latitud" %in% names(negocios)) "latitud" else if("lat" %in% names(negocios)) "lat" else NULL
        lng_col <- if("longitud" %in% names(negocios)) "longitud" else if("lng" %in% names(negocios)) "lng" else NULL
        name_col <- if("nombre" %in% names(negocios)) "nombre" else if("Nombre" %in% names(negocios)) "Nombre" else names(negocios)[1]
        
        if (!is.null(lat_col) && !is.null(lng_col)) {
          proxy %>%
            addMarkers(
              lng = as.numeric(negocios[[lng_col]]),
              lat = as.numeric(negocios[[lat_col]]),
              popup = negocios[[name_col]],
              group = "markers"
            )
        }
      }
    })
    
    # Renderizar histograma
    output$histograma <- renderPlot({
      req(input$variable)
      req(agebs_hex)
      
      variable_data <- agebs_hex[[input$variable]]
      if (all(is.na(variable_data))) {
        variable_data <- rep(1, nrow(agebs_hex))
      }
      
      hist(variable_data, 
           breaks = 20, 
           col = "#7A9E7E", 
           border = "white",
           main = "Distribución del Perfil Seleccionado", 
           xlab = input$variable,
           ylab = "Frecuencia")
    })
  })
}