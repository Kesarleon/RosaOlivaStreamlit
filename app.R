# Rosa Oliva Geoespacial - app principal
#
# Main application file for the Shiny dashboard.
# This file defines the UI and server logic, and sources global configurations,
# data, and UI/server modules.
#
# Main R Packages Used:
# - shiny: Web Application Framework for R
# - shinydashboard: Create Dashboards with 'Shiny'
# - leaflet: Interactive Web Maps with the JavaScript 'Leaflet' Library
# - dplyr: A Grammar of Data Manipulation
# - sf: Simple Features for R
# - tidyr: Tidy Messy Data
# - DT: A Wrapper of the JavaScript Library 'DataTables'
# - tidyverse: Easily Install and Load the 'Tidyverse'
# - jsonlite: A Robust, High Performance JSON Parser and Generator for R
# - googleway: Retrieves Data from 'Google Maps' APIs
# - shinyjs: Easily Improve the User Experience of Your Shiny Apps in Seconds
# - geosphere: Spherical Trigonometry

library(shiny)
library(shinydashboard)
library(leaflet)
library(dplyr)
library(sf)
library(tidyr)
library(DT)

# Cargar configuraciones y datos
source("global.R") # Contains global variables, data loading, and utility functions

# Cargar módulos (UI and server components for each tab)
source("modules/mod_mapa.R")
source("modules/mod_huff.R")
source("modules/mod_socio.R")
source("modules/mod_agente.R")

#' Defines the user interface (UI) for the Shiny application.
#'
#' This function sets up the overall layout of the dashboard, including the
#' header, sidebar, and body. It defines the navigation menu and the content
#' areas for different modules.
#'
#' @return A `dashboardPage` Shiny UI object.
#' @export
ui <- dashboardPage(
  dashboardHeader(
    title = tags$a(
      href = '#', # Or a relevant link like the app's URL if hosted
      tags$img(
        src = 'logo_ro.png', # Assumes logo_ro.png is in www/
        title = "Rosa Oliva Geoespacial",
        height = "40px", # Adjust height as needed
        style = "padding-top:5px; padding-bottom:5px; margin-right: 5px;" # Vertical padding and right margin
      ),
      "Rosa Oliva Geoespacial" # Title text next to the logo
    )
  ),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Mapa", tabName = "mapa", icon = icon("map")),
      menuItem("Análisis Captación", tabName = "huff", icon = icon("chart-area")),
      menuItem("Socioeconómico", tabName = "socio", icon = icon("layer-group")),
      menuItem("Agente Expansión", tabName = "agente", icon = icon("lightbulb"))
    )
  ),
  dashboardBody(
    # CSS personalizado si existe
    if (file.exists("www/theme.css")) {
      includeCSS("www/theme.css")
    },
    # Favicon si existe
    tags$head(
      if (file.exists("www/favicon/favicon.ico")) {
        tags$link(rel = "shortcut icon", href = "www/favicon/favicon.ico") # Corrected href path
      }
    ),
    tabItems(
      tabItem(tabName = "mapa", mod_mapa_ui("mapa_ui")),
      tabItem(tabName = "huff", mod_huff_ui("huff_ui")),
      tabItem(tabName = "socio", mod_socio_ui("socio_ui")),
      tabItem(tabName = "agente", mod_agente_ui("agente_ui"))
    )
  )
)

#' Defines the server-side logic for the Shiny application.
#'
#' This function initializes and manages the server-side components of the
#' application. It calls the server functions for each of the loaded modules,
#' enabling reactive data processing and dynamic output generation.
#'
#' @param input A list-like object containing all the reactive input values from the UI.
#' @param output A list-like object for storing all the reactive output values to be displayed in the UI.
#' @param session A special object that provides information and control over the user's session.
#' @return This function does not explicitly return a value but sets up reactive logic.
#' @export
server <- function(input, output, session) {
  # Llamar servidores de módulos
  map_data <- mod_mapa_server("mapa_ui")
  mod_huff_server("huff_ui", map_data)
  mod_socio_server("socio_ui")
  mod_agente_server("agente_ui")
}

# Manejar errores de la aplicación
options(shiny.error = function() {
  cat("Error en la aplicación Shiny\n")
  # One could also redirect to an error page or show a custom message in the UI.
  # For example: shinyjs::alert("An unexpected error occurred. Please contact support.")
})

shinyApp(ui, server)
