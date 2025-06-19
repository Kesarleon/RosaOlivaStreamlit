# Módulo para cálculo de Huff entre sucursales y competencia

source("utils/huff_model.R", local = TRUE)
source("utils/google_places.R", local = TRUE)

mod_huff_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        width = 4,
        selectInput(
          ns("sucursal"),
          "Sucursal Rosa Oliva:",
          choices = APP_CONFIG$sucursales_rosa_data$nombre # From APP_CONFIG
        ),
        actionButton(ns("calcular"), "Calcular captación", class = "btn-primary"),
        br(), br(),
        h4("Parámetros del modelo:"),
        numericInput(ns("alfa"), "Atractivo (α):",
                     value = APP_CONFIG$huff_default_alfa, # From APP_CONFIG
                     min = 0.1, max = 3, step = 0.1),
        numericInput(ns("beta"), "Fricción distancia (β):",
                     value = APP_CONFIG$huff_default_beta, # From APP_CONFIG
                     min = 0.1, max = 5, step = 0.1)
      ),
      column(
        width = 8,
        h4("Resultados de captación"),
        DT::dataTableOutput(ns("tabla_resultados")),
        br(),
        h4("Mapa de análisis"),
        leaflet::leafletOutput(ns("mapa_huff"), height = "400px")
      )
    )
  )
}

mod_huff_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    if (!nzchar(Sys.getenv("GOOGLE_PLACES_API_KEY"))) {
      shiny::showNotification(
        "Advertencia: GOOGLE_PLACES_API_KEY no configurada. Atractividad de competencia usará valores por defecto.",
        type = "warning",
        duration = NULL
      )
    }
    
    # --- Reactive Data Definitions ---
    sucursales_rosa <- reactive({
      APP_CONFIG$sucursales_rosa_data # From APP_CONFIG
    })
    
    competencia_base <- reactive({
      APP_CONFIG$competencia_base_data # From APP_CONFIG
    })
    
    competencia <- reactive({
      df <- competencia_base()
      if (nrow(df) == 0) {
        return(df)
      }
      df$atractivo <- DEFAULT_RATING
      for (i in 1:nrow(df)) {
        rating <- get_google_place_rating(
          place_name = df$nombre[i],
          lat = df$lat[i],
          lng = df$lng[i]
        )
        df$atractivo[i] <- rating
      }
      return(df)
    })

    req(agebs_hex)

    agebs_data <- reactive({
      if (exists("agebs_hex") && is.data.frame(get("agebs_hex")) && nrow(get("agebs_hex")) > 0) {
        local_agebs_hex <- get("agebs_hex")

        # Ensure necessary columns for processing are present
        required_cols <- c("id_hex", "clientes_totales") # Add any other essential non-geometry columns
        missing_cols <- setdiff(required_cols, names(local_agebs_hex))
        if (length(missing_cols) > 0) {
          stop(paste("Columnas requeridas faltantes en agebs_hex:", paste(missing_cols, collapse = ", ")))
        }

        tryCatch({
          # Dynamically find the sfc geometry column
          sfc_column_indices <- which(sapply(local_agebs_hex, function(col) inherits(col, "sfc")))

          if (length(sfc_column_indices) == 0) {
            stop("No sfc geometry column found in agebs_hex.")
          }

          geom_col_name <- names(local_agebs_hex)[sfc_column_indices[1]]
          # message(paste("Using geometry column:", geom_col_name)) # For debugging

          # Additional safety check (might be redundant if the above is robust)
          if (!inherits(local_agebs_hex[[geom_col_name]], "sfc")) {
            stop(paste("Column '", geom_col_name, "' is not an sfc column despite initial detection."))
          }

          # Proceed with centroid calculation using the dynamically found geometry column
          centroids_sf <- sf::st_centroid(local_agebs_hex[[geom_col_name]])
          coords <- sf::st_coordinates(centroids_sf)

          data.frame(
            cvegeo = local_agebs_hex$id_hex, # Assuming id_hex exists
            lat = coords[, 2],
            lng = coords[, 1],
            poblacion = local_agebs_hex$clientes_totales, # Assuming clientes_totales exists
            stringsAsFactors = FALSE
          )
        }, error = function(e) {
          shiny::showNotification(paste("Error procesando agebs_hex:", e$message), type = "error")
          message(paste("Detailed error in agebs_data reactive:", e)) # More detailed console log
          # Return an empty data.frame with the expected structure in case of error
          data.frame(
            cvegeo = character(), lat = numeric(), lng = numeric(),
            poblacion = numeric(), stringsAsFactors = FALSE
          )
        })
      } else {
        shiny::showNotification("Usando datos AGEB simulados (agebs_hex no disponible o vacío).", type = "message")
        # Fallback to simulated data if agebs_hex is not available
        data.frame(
          cvegeo = paste0("AGBSIM", 1:20),
          lat = runif(20, 17.04, 17.08),
          lng = runif(20, -96.74, -96.70),
          poblacion = sample(200:1500, 20, replace = TRUE),
          stringsAsFactors = FALSE
        )
      }
    })
    
    # --- Calculation Logic ---
    resultados <- eventReactive(input$calcular, {
      req(input$sucursal, agebs_data(), competencia())
      
      if (nrow(agebs_data()) == 0) {
        shiny::showNotification("No hay datos de AGEBs disponibles para el cálculo.", type = "error")
        return(data.frame(Error = "Datos de AGEBs no disponibles.", stringsAsFactors = FALSE))
      }
      
      id_calc_notif <- shiny::showNotification("Calculando captación...", type = "message", duration = NULL)
      on.exit(shiny::removeNotification(id_calc_notif), add = TRUE)
      
      tryCatch({
        suc_sel <- sucursales_rosa() %>% dplyr::filter(nombre == input$sucursal)
        if (nrow(suc_sel) == 0) {
          stop("Sucursal seleccionada no encontrada.")
        }
        
        comp_data <- competencia()
        todos_puntos <- dplyr::bind_rows(
          suc_sel %>% dplyr::mutate(tipo = "Rosa Oliva"),
          comp_data %>% dplyr::mutate(tipo = "Competencia")
        )
        
        current_agebs <- agebs_data()
        
        resultados_list <- lapply(1:nrow(current_agebs), function(i) {
          res_huff <- huff_model(
            ag_lat = current_agebs$lat[i],
            ag_lng = current_agebs$lng[i],
            puntos = todos_puntos,
            alfa = input$alfa,
            beta = input$beta
          )
          data.frame(
            cvegeo = current_agebs$cvegeo[i],
            poblacion = current_agebs$poblacion[i],
            agebs_lat = current_agebs$lat[i],
            agebs_lng = current_agebs$lng[i],
            res_huff,
            stringsAsFactors = FALSE
          )
        })
        resultados_detalle <- dplyr::bind_rows(resultados_list)
        
        total_poblacion_agebs <- sum(current_agebs$poblacion, na.rm = TRUE)
        if (total_poblacion_agebs == 0) {
          stop("La población total de los AGEBs es cero. No se puede calcular participación.")
        }
        
        captacion_resumen <- resultados_detalle %>%
          dplyr::group_by(id, nombre, tipo) %>%
          dplyr::summarise(
            captacion_total = sum(prob * poblacion, na.rm = TRUE),
            participacion = round((sum(prob * poblacion, na.rm = TRUE) / total_poblacion_agebs) * 100, 2),
            agebs_influencia = dplyr::n_distinct(cvegeo[prob > 0.4 & is.finite(prob)]),
            .groups = "drop"
          ) %>%
          dplyr::arrange(desc(captacion_total))
        
        session$userData$resultados_detalle <- resultados_detalle
        return(captacion_resumen)
        
      }, error = function(e) {
        shiny::showNotification(paste("Error en cálculo:", e$message), type = "error", duration = 10)
        message("Error en eventReactive resultados: ", e$message)
        return(data.frame(Error = as.character(e$message), stringsAsFactors = FALSE))
      })
    })
    
    # --- Outputs ---
    output$tabla_resultados <- DT::renderDataTable({
      res <- resultados()
      req(res)

      if ("Error" %in% names(res)) {
        DT::datatable(res[, "Error", drop = FALSE], options = list(dom = 't'))
      } else {
        DT::datatable(
          res %>% dplyr::select(
            Negocio = nombre, Tipo = tipo, `Captación estimada` = captacion_total,
            `Participación (%)` = participacion, `AGEBs influencia` = agebs_influencia
          ),
          options = list(pageLength = 5, dom = 'Bfrtip', buttons = c('copy', 'csv', 'excel')),
          rownames = FALSE, extensions = 'Buttons'
        ) %>% DT::formatRound(c("Captación estimada"), digits = 0)
      }
    })
    
    output$mapa_huff <- leaflet::renderLeaflet({
      leaflet::leaflet() %>%
        leaflet::addProviderTiles("CartoDB.Positron") %>%
        leaflet::setView(lng = APP_CONFIG$default_lng, lat = APP_CONFIG$default_lat, zoom = 13) # Use APP_CONFIG
    })
    
    observe({
      res_data_map <- resultados()
      req(res_data_map)
      
      if (!"Error" %in% names(res_data_map) && !is.null(session$userData$resultados_detalle)) {
        detalle_map <- session$userData$resultados_detalle
        suc_sel_nombre_map <- input$sucursal
        
        ageb_perf_selected_store_map <- detalle_map %>%
          dplyr::filter(nombre == suc_sel_nombre_map & tipo == "Rosa Oliva")

        proxy <- leaflet::leafletProxy("mapa_huff", data = ageb_perf_selected_store_map)
        proxy %>% leaflet::clearMarkers() %>% leaflet::clearShapes() %>% leaflet::clearControls()
        
        if (nrow(ageb_perf_selected_store_map) > 0) {
          prob_domain <- ageb_perf_selected_store_map$prob
          if (all(is.na(prob_domain)) || length(unique(na.omit(prob_domain))) <= 1) {
            pal <- leaflet::colorNumeric("Reds", domain = c(0, 1), na.color = "transparent")
          } else {
            pal <- leaflet::colorNumeric("Reds", domain = prob_domain, na.color = "transparent")
          }
          
          proxy %>%
            leaflet::addAwesomeMarkers(
              data = sucursales_rosa(),
              lng = ~lng, lat = ~lat,
              popup = ~paste0("<b>", nombre, "</b><br>Atractivo (interno): ", atractivo),
              layerId = ~paste0("suc_", id),
              icon = leaflet::awesomeIcons(icon = "store", library = "fa", markerColor = "darkgreen")
            ) %>%
            leaflet::addAwesomeMarkers(
              data = competencia(),
              lng = ~lng, lat = ~lat,
              popup = ~paste0("<b>", nombre, "</b><br>Atractivo (Google): ", round(atractivo, 2)),
              layerId = ~paste0("comp_", id),
              icon = leaflet::awesomeIcons(icon = "store", library = "fa", markerColor = "black")
            ) %>%
            leaflet::addCircleMarkers(
              lng = ~agebs_lng, lat = ~agebs_lat,
              radius = ~ scales::rescale(sqrt(poblacion), to = c(3, 12)),
              color = ~pal(prob),
              fillOpacity = 0.6,
              stroke = TRUE, weight = 1,
              layerId = ~paste0("ageb_", cvegeo),
              popup = ~paste0(
                "<b>AGEB: ", cvegeo, "</b><br>",
                "Población (clientes potenciales): ", scales::comma(poblacion, accuracy = 1), "<br>",
                "Prob. captación (", suc_sel_nombre_map, "): ", scales::percent(prob, accuracy = 0.1)
              )
            ) %>%
            leaflet::addLegend(
              position = "bottomright",
              pal = pal,
              values = ~prob,
              title = paste0("Prob. Captación<br>", suc_sel_nombre_map),
              opacity = 1,
              layerId = "legend_huff"
            )
        }
      }
    })
  }) # End moduleServer
}
