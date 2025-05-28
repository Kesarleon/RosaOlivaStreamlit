# Módulo para cálculo de Huff entre sucursales y competencia

# modules/mod_huff.R

mod_huff_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        width = 4,
        selectInput(ns("sucursal"), "Sucursal Rosa Oliva:", choices = c("Sucursal A", "Sucursal B", "Sucursal C")),
        actionButton(ns("calcular"), "Calcular captación")
      ),
      column(
        width = 8,
        DT::dataTableOutput(ns("tabla_resultados"))
      )
    )
  )
}

mod_huff_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Simular datos de sucursales Rosa Oliva y competencia
    sucursales_rosa <- data.frame(
      id = c("A", "B", "C"),
      nombre = c("Sucursal A", "Sucursal B", "Sucursal C"),
      lat = c(17.06, 17.07, 17.05),
      lng = c(-96.72, -96.73, -96.71),
      atractivo = c(4.5, 4.0, 4.2) # Rating interno
    )
    
    competencia <- data.frame(
      id = c("X", "Y", "Z"),
      nombre = c("Joyería X", "Joyería Y", "Joyería Z"),
      lat = c(17.065, 17.068, 17.052),
      lng = c(-96.725, -96.732, -96.713),
      atractivo = c(4.1, 3.9, 4.3) # Simulado desde Google Places API
    )
    
    # Simular AGEBS cercanas con población
    agebs <- data.frame(
      cvegeo = paste0("AGB", 1:10),
      lat = runif(10, 17.05, 17.08),
      lng = runif(10, -96.74, -96.70),
      poblacion = sample(200:1500, 10)
    )
    
    # Función del modelo de Huff
    huff_model <- function(ag_lat, ag_lng, puntos) {
      puntos$distancia <- geosphere::distHaversine(
        cbind(puntos$lng, puntos$lat),
        c(ag_lng, ag_lat)
      )
      puntos$utilidad <- puntos$atractivo / (puntos$distancia + 1)
      puntos$prob <- puntos$utilidad / sum(puntos$utilidad)
      puntos
    }
    
    resultados <- eventReactive(input$calcular, {
      # Seleccionar sucursal
      suc_sel <- sucursales_rosa %>%
        filter(nombre == input$sucursal)
      
      # Unir competencia + sucursal seleccionada
      puntos <- bind_rows(suc_sel, competencia)
      
      # Aplicar modelo a cada AGEB
      captacion <- agebs %>%
        rowwise() %>%
        mutate(result = list(huff_model(lat, lng, puntos))) %>%
        unnest(result) %>%
        filter(nombre == input$sucursal) %>%
        group_by(nombre) %>%
        summarise(
          captacion = sum(prob * poblacion),
          poblacion_zona = sum(poblacion)
        )
      
      # Armar tabla
      tibble(
        Sucursal = input$sucursal,
        `Población objetivo` = captacion$poblacion_zona,
        `Captación estimada` = round(captacion$captacion, 0)
      )
    })
    
    output$tabla_resultados <- DT::renderDataTable({
      req(resultados())
      DT::datatable(resultados(), options = list(pageLength = 5))
    })
  })
}
