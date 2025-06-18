# Módulo para cálculo de Huff entre sucursales y competencia

source("../utils/huff_model.R", local = TRUE)

mod_huff_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        width = 4,
        selectInput(ns("sucursal"), "Sucursal Rosa Oliva:", 
                    choices = c("Sucursal A", "Sucursal B", "Sucursal C")),
        actionButton(ns("calcular"), "Calcular captación", class = "btn-primary"),
        br(), br(),
        h4("Parámetros del modelo:"),
        numericInput(ns("alfa"), "Atractivo (α):", value = 1, min = 0.1, max = 3, step = 0.1),
        numericInput(ns("beta"), "Fricción distancia (β):", value = 2, min = 0.1, max = 5, step = 0.1)
      ),
      column(
        width = 8,
        h4("Resultados de captación"),
        DT::dataTableOutput(ns("tabla_resultados")),
        br(),
        h4("Mapa de análisis"),
        leafletOutput(ns("mapa_huff"), height = 400)
      )
    )
  )
}

mod_huff_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Datos de sucursales Rosa Oliva
    sucursales_rosa <- reactive({
      data.frame(
        id = c("A", "B", "C"),
        nombre = c("Sucursal A", "Sucursal B", "Sucursal C"),
        lat = c(17.0788831, 17.07, 17.05),
        lng = c(-96.7130538, -96.73, -96.71),
        atractivo = c(4.5, 4.0, 4.2) # Rating interno
      )
    })
    
    # Datos de competencia
    competencia <- reactive({
      data.frame(
        id = c("X", "Y", "Z"),
        nombre = c("Joyería X", "Joyería Y", "Joyería Z"),
        lat = c(17.065, 17.068, 17.052),
        lng = c(-96.725, -96.732, -96.713),
        atractivo = c(4.1, 3.9, 4.3) # Simulado desde Google Places API
      )
    })
    
    # AGEBS cercanas con población
    agebs_data <- reactive({
      if (exists("agebs_hex") && nrow(agebs_hex) > 0) {
        # Usar datos reales si están disponibles
        coords <- st_coordinates(st_centroid(agebs_hex))
        data.frame(
          cvegeo = agebs_hex$id_hex,
          lat = coords[,2],
          lng = coords[,1],
          poblacion = agebs_hex$poblacion
        )
      } else {
        # Datos simulados
        data.frame(
          cvegeo = paste0("AGB", 1:20),
          lat = runif(20, 17.04, 17.08),
          lng = runif(20, -96.74, -96.70),
          poblacion = sample(200:1500, 20, replace = TRUE)
        )
      }
    })
    
    # Cálculo de resultados
    resultados <- eventReactive(input$calcular, {
      req(input$sucursal)
      
      tryCatch({
        # Seleccionar sucursal
        suc_sel <- sucursales_rosa() %>%
          filter(nombre == input$sucursal)
        
        if (nrow(suc_sel) == 0) {
          return(data.frame(Error = "Sucursal no encontrada"))
        }
        
        # Unir competencia + sucursal seleccionada
        todos_puntos <- bind_rows(
          suc_sel %>% mutate(tipo = "Rosa Oliva"),
          competencia() %>% mutate(tipo = "Competencia")
        )
        
        # Aplicar modelo a cada AGEB
        agebs <- agebs_data()
        
        resultados_detalle <- agebs %>%
          rowwise() %>%
          mutate(
            resultado_huff = list(huff_model(lat, lng, todos_puntos, input$alfa, input$beta))
          ) %>%
          unnest(resultado_huff) %>%
          ungroup()
        
        # Calcular captación por sucursal
        captacion_resumen <- resultados_detalle %>%
          group_by(nombre, tipo) %>%
          summarise(
            captacion_total = sum(prob * poblacion, na.rm = TRUE),
            participacion = round(captacion_total / sum(poblacion) * 100, 2),
            agebs_influencia = n_distinct(cvegeo),
            .groups = "drop"
          ) %>%
          arrange(desc(captacion_total))
        
        # Guardar detalles para el mapa
        session$userData$resultados_detalle <- resultados_detalle
        
        return(captacion_resumen)
        
      }, error = function(e) {
        showNotification(paste("Error en cálculo:", e$message), type = "error")
        return(data.frame(Error = paste("Error:", e$message)))
      })
    })
    
    # Tabla de resultados
    output$tabla_resultados <- DT::renderDataTable({
      req(resultados())
      
      if ("Error" %in% names(resultados())) {
        DT::datatable(resultados(), options = list(pageLength = 5, dom = 't'))
      } else {
        DT::datatable(
          resultados() %>%
            select(
              Negocio = nombre,
              Tipo = tipo,
              `Captación estimada` = captacion_total,
              `Participación (%)` = participacion,
              `AGEBs influencia` = agebs_influencia
            ),
          options = list(pageLength = 10, dom = 'ft'),
          rownames = FALSE
        ) %>%
          DT::formatRound(c("Captación estimada"), digits = 0) %>%
          DT::formatStyle(
            "Tipo",
            backgroundColor = DT::styleEqual("Rosa Oliva", "#e8f5e8")
          )
      }
    })
    
    # Mapa de resultados
    output$mapa_huff <- renderLeaflet({
      leaflet() %>%
        addProviderTiles("CartoDB.Positron") %>%
        setView(lng = -96.72, lat = 17.06, zoom = 12)
    })
    
    # Actualizar mapa cuando hay resultados
    observe({
      req(resultados())
      
      if (!"Error" %in% names(resultados()) && !is.null(session$userData$resultados_detalle)) {
        detalle <- session$userData$resultados_detalle
        
        # Datos para Rosa Oliva
        rosa_data <- detalle %>% filter(tipo == "Rosa Oliva")
        
        # Crear paleta de colores para probabilidad
        if (nrow(rosa_data) > 0) {
          pal <- colorNumeric("Reds", domain = rosa_data$prob)
          
          leafletProxy("mapa_huff") %>%
            clearMarkers() %>%
            clearShapes() %>%
            # Agregar sucursales
            addMarkers(
              data = sucursales_rosa(),
              lng = ~lng, lat = ~lat,
              popup = ~paste("<b>", nombre, "</b><br>Atractivo:", atractivo),
              icon = list(iconUrl = "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png",
                          iconWidth = 25, iconHeight = 41)
            ) %>%
            # Agregar competencia
            addMarkers(
              data = competencia(),
              lng = ~lng, lat = ~lat,
              popup = ~paste("<b>", nombre, "</b><br>Atractivo:", atractivo),
              icon = list(iconUrl = "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png",
                          iconWidth = 25, iconHeight = 41)
            ) %>%
            # Agregar círculos por AGEB con intensidad de captación
            addCircleMarkers(
              data = rosa_data,
              lng = ~lng, lat = ~lat,
              radius = ~sqrt(poblacion) / 10,
              color = ~pal(prob),
              fillOpacity = 0.7,
              stroke = TRUE,
              popup = ~paste("<b>AGEB:", cvegeo, "</b><br>",
                             "Población:", poblacion, "<br>",
                             "Probabilidad captación:", round(prob * 100, 1), "%")
            ) %>%
            addLegend(
              position = "bottomright",
              pal = pal,
              values = rosa_data$prob,
              title = "Prob. Captación<br>Rosa Oliva"
            )
        }
      }
    })
  })
}