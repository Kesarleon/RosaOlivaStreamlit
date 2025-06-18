# Módulo para cálculo de Huff entre sucursales y competencia

source("utils/huff_model.R", local = TRUE)
source("utils/google_places.R", local = TRUE) # Added this line

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
        leaflet::leafletOutput(ns("mapa_huff"), height = 400)
      )
    )
  )
}

mod_huff_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    if (Sys.getenv("GOOGLE_PLACES_API_KEY") == "") {
      shiny::showNotification(
        "Advertencia: GOOGLE_PLACES_API_KEY no configurada. Atractividad de competencia usará valores por defecto.",
        type = "warning",
        duration = NULL
      )
    }
    
    sucursales_rosa <- reactive({
      data.frame(
        id = c("A", "B", "C"),
        nombre = c("Sucursal A", "Sucursal B", "Sucursal C"),
        lat = c(17.0788831, 17.07, 17.05),
        lng = c(-96.7130538, -96.73, -96.71),
        atractivo = c(4.5, 4.0, 4.2),
        stringsAsFactors = FALSE
      )
    })
    
    competencia_base <- reactive({
      data.frame(
        id = c("X", "Y", "Z"),
        nombre = c("Joyería X", "Joyería Y", "Joyería Z"),
        lat = c(17.065, 17.068, 17.052),
        lng = c(-96.725, -96.732, -96.713),
        stringsAsFactors = FALSE
      )
    })
    
    competencia <- reactive({
      df <- competencia_base()
      if (nrow(df) == 0) return(df) # Return empty if no base competitors
      
      # Initialize atractivo column first
      df$atractivo <- DEFAULT_RATING # Assuming DEFAULT_RATING is defined in google_places.R or use a numeric value like 3.0
      
      # Fetch ratings
      # Using a simple loop for API calls to avoid overwhelming the API or complex reactive handling
      for (i in 1:nrow(df)) {
        # message(paste("Fetching rating for:", df$nombre[i])) # Debugging
        rating <- get_google_place_rating(
          place_name = df$nombre[i],
          lat = df$lat[i],
          lng = df$lng[i]
        )
        df$atractivo[i] <- rating
        # message(paste("Rating for", df$nombre[i], ":", rating)) # Debugging
      }
      return(df)
    })
    req(agebs_hex)
    agebs_data <- reactive({
      if (exists("agebs_hex") && is.data.frame(get("agebs_hex")) && nrow(get("agebs_hex")) > 0) {
        local_agebs_hex <- get("agebs_hex")
        tryCatch({
          # Ensure the geometry column is correctly referenced, common names are 'geometry' or 'geom'
          geom_col_name <- 'geometry'#names(which(sapply(local_agebs_hex, class) == "sfc"))[1]
          if (is.na(geom_col_name)) stop("No sfc geometry column found in agebs_hex")
          coords <- sf::st_coordinates(sf::st_centroid(local_agebs_hex[[geom_col_name]]))
          data.frame(
            cvegeo = local_agebs_hex$id_hex,
            lat = coords[,2],
            lng = coords[,1],
            poblacion = local_agebs_hex$clientes_totales,
            stringsAsFactors = FALSE
          )
        }, error = function(e){
          shiny::showNotification(paste("Error procesando agebs_hex:", e$message), type="error")
          data.frame(cvegeo=character(), lat=numeric(), lng=numeric(), poblacion=numeric(), stringsAsFactors = FALSE) # Return empty df on error
        })
      } else {
        data.frame(
          cvegeo = paste0("AGBSIM", 1:20),
          lat = runif(20, 17.04, 17.08),
          lng = runif(20, -96.74, -96.70),
          poblacion = sample(200:1500, 20, replace = TRUE),
          stringsAsFactors = FALSE
        )
      }
    })
    
    resultados <- eventReactive(input$calcular, {
      req(input$sucursal, agebs_data(), competencia())
      
      if(nrow(agebs_data()) == 0){
        shiny::showNotification("No hay datos de AGEBs disponibles para el cálculo.", type="error")
        return(data.frame(Error = "Datos de AGEBs no disponibles", stringsAsFactors = FALSE))
      }
      
      id_calc_notif <- shiny::showNotification("Calculando captación...", type = "message", duration = NULL)
      on.exit(shiny::removeNotification(id_calc_notif), add = TRUE)
      
      tryCatch({
        suc_sel <- sucursales_rosa() %>% dplyr::filter(nombre == input$sucursal)
        if (nrow(suc_sel) == 0) stop("Sucursal seleccionada no encontrada.")
        
        comp_data <- competencia()
        todos_puntos <- dplyr::bind_rows(suc_sel %>% dplyr::mutate(tipo = "Rosa Oliva"),
                                         comp_data %>% dplyr::mutate(tipo = "Competencia"))
        
        current_agebs <- agebs_data()
        
        resultados_list <- lapply(1:nrow(current_agebs), function(i) {
          res_huff <- huff_model(current_agebs$lat[i], current_agebs$lng[i], todos_puntos, input$alfa, input$beta)
          cbind(cvegeo = current_agebs$cvegeo[i],
                poblacion = current_agebs$poblacion[i],
                agebs_lat = current_agebs$lat[i],
                agebs_lng = current_agebs$lng[i],
                res_huff,
                stringsAsFactors = FALSE)
        })
        resultados_detalle <- dplyr::bind_rows(resultados_list)
        
        total_poblacion_agebs <- sum(current_agebs$poblacion, na.rm = TRUE)
        if(total_poblacion_agebs == 0) stop("La población total de los AGEBs es cero.")
        
        captacion_resumen <- resultados_detalle %>%
          dplyr::group_by(id, nombre, tipo) %>%
          dplyr::summarise(
            captacion_total = sum(prob * poblacion, na.rm = TRUE),
            participacion = round((sum(prob * poblacion, na.rm = TRUE) / total_poblacion_agebs) * 100, 2),
            agebs_influencia = dplyr::n_distinct(cvegeo[prob > 0]), # Count only AGEBs with some probability
            .groups = "drop"
          ) %>%
          dplyr::arrange(desc(captacion_total))
        
        session$userData$resultados_detalle <- resultados_detalle
        return(captacion_resumen)
        
      }, error = function(e) {
        shiny::showNotification(paste("Error en cálculo:", e$message), type = "error", duration = 10)
        message("Error en eventReactive resultados: ", e$message) # Console log for debugging
        return(data.frame(Error = e$message, stringsAsFactors = FALSE))
      })
    })
    
    output$tabla_resultados <- DT::renderDataTable({
      res <- resultados()
      req(res)
      if ("Error" %in% names(res)) {
        DT::datatable(res[, "Error", drop=FALSE], options = list(dom = 't'))
      } else {
        DT::datatable(
          res %>% dplyr::select(Negocio = nombre, Tipo = tipo, `Captación estimada` = captacion_total,
                                `Participación (%)` = participacion, `AGEBs influencia` = agebs_influencia),
          options = list(pageLength = 10, dom = 'Bfrtip', buttons = c('copy', 'csv', 'excel')),
          rownames = FALSE, extensions = 'Buttons'
        ) %>% DT::formatRound(c("Captación estimada"), digits = 0)
      }
    })
    
    output$mapa_huff <- leaflet::renderLeaflet({
      leaflet::leaflet() %>%
        leaflet::addProviderTiles("CartoDB.Positron") %>%
        leaflet::setView(lng = -96.72, lat = 17.06, zoom = 13)
    })
    
    observe({
      res_data_map <- resultados()
      req(res_data_map)
      
      if (!"Error" %in% names(res_data_map) && !is.null(session$userData$resultados_detalle)) {
        detalle_map <- session$userData$resultados_detalle
        suc_sel_nombre_map <- input$sucursal
        
        ageb_perf_selected_store_map <- detalle_map %>%
          dplyr::filter(nombre == suc_sel_nombre_map & tipo == "Rosa Oliva")
        
        # Ensure leafletProxy is called with data if it's going to be used in chained expressions
        proxy <- leaflet::leafletProxy("mapa_huff", data = ageb_perf_selected_store_map)
        proxy %>% leaflet::clearMarkers() %>% leaflet::clearShapes() %>% leaflet::clearControls()
        
        if (nrow(ageb_perf_selected_store_map) > 0) {
          pal <- leaflet::colorNumeric("Reds", domain = ageb_perf_selected_store_map$prob, na.color = "transparent")
          
          proxy %>%
            leaflet::addMarkers(
              data = sucursales_rosa(),
              lng = ~lng, lat = ~lat,
              popup = ~paste0("<b>", nombre, "</b><br>Atractivo (interno): ", atractivo),
              layerId = ~paste0("suc_", id),
              icon = leaflet::makeIcon(iconUrl = "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png", iconWidth = 25, iconHeight = 41)
            ) %>%
            leaflet::addMarkers(
              data = competencia(),
              lng = ~lng, lat = ~lat,
              popup = ~paste0("<b>", nombre, "</b><br>Atractivo (Google): ", round(atractivo, 2)),
              layerId = ~paste0("comp_",id),
              icon = leaflet::makeIcon(iconUrl = "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png", iconWidth = 25, iconHeight = 41)
            ) %>%
            leaflet::addCircleMarkers(
              lng = ~agebs_lng, lat = ~agebs_lat,
              radius = ~sqrt(poblacion) / 1, # Adjusted radius slightly
              color = ~pal(prob),
              fillOpacity = 0.6,
              stroke = TRUE, weight = 1,
              layerId = ~paste0("ageb_",cvegeo),
              popup = ~paste0("<b>AGEB: ", cvegeo, "</b><br>Población: ", poblacion,
                              "<br>Prob. captación (", suc_sel_nombre_map, "): ", round(prob * 100, 1), "%")
            ) %>%
            leaflet::addLegend(
              position = "bottomright", pal = pal, values = ~prob,
              title = paste0("Prob. Captación<br>", suc_sel_nombre_map), opacity = 1,
              layerId = "legend_huff"
            )
        }
      }
    })
  })
}