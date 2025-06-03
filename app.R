
# Rosa Oliva Geoespacial - app principal
library(shiny)
library(shinydashboard)
library(leaflet)
library(dplyr)
library(sf)
library(tidyr)

source('global.R')
source("modules/mod_mapa.R")
source("modules/mod_huff.R")
source("modules/mod_socio.R")
source("modules/mod_agente.R")

token_google_maps <- Sys.getenv("GOOGLE_MAPS_TOKEN")  # <- Reemplaza para uso real

ui <- dashboardPage(
  dashboardHeader(title = "Rosa Oliva Geoespacial"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Mapa", tabName = "mapa", icon = icon("map")),
      menuItem("Análisis Captación", tabName = "huff", icon = icon("chart-area")),
      menuItem("Socioeconómico", tabName = "socio", icon = icon("layer-group")),
      menuItem("Agente Expansión", tabName = "agente", icon = icon("lightbulb"))
    )
  ),
  dashboardBody(
    includeCSS("www/theme.css"),
    tags$head(tags$link(rel = "shortcut icon", href = "www/favicon/favicon.ico")),
    tabItems(
      tabItem(tabName = "mapa", mod_mapa_ui("mapa_ui")),
      tabItem(tabName = "huff", mod_huff_ui("huff_ui")),
      tabItem(tabName = "socio", mod_socio_ui("socio_ui")),
      tabItem(tabName = "agente", mod_agente_ui("agente_ui"))
    )
  )
)

server <- function(input, output, session) {
  mod_mapa_server("mapa_ui")
  mod_huff_server("huff_ui")
  mod_socio_server("socio_ui")
  mod_agente_server("agente_ui")
}

shinyApp(ui, server)
