# utils/google_places.R

library(httr)
library(jsonlite)

# Default rating to use if a place has no rating or an error occurs
DEFAULT_RATING <- 3.0 # Or NA, depending on desired behavior for missing ratings

#' Fetch Google Place Rating
#'
#' Searches for a place using Google Places API (Text Search) based on its name and location,
#' then retrieves its rating.
#'
#' @param place_name The name of the place (e.g., "Restaurante El Sazón").
#' @param lat Latitude of the place.
#' @param lng Longitude of the place.
#' @param api_key Google Places API key. Defaults to `Sys.getenv("GOOGLE_PLACES_API_KEY")`.
#' @param radius Search radius in meters. Default is 50 meters to narrow down search.
#' @return The Google Places rating (numeric) or DEFAULT_RATING if not found or in case of error.
get_google_place_rating <- function(place_name, lat, lng, api_key = Sys.getenv("GOOGLE_PLACES_API_KEY"), radius = 50) {
  
  if (api_key == "") {
    warning("Google Places API key is missing. Set GOOGLE_PLACES_API_KEY environment variable. Returning default rating.", call. = FALSE)
    return(DEFAULT_RATING)
  }
  
  if (!is.numeric(lat) || !is.numeric(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    warning(paste0("Invalid coordinates for ", place_name, ": lat=", lat, ", lng=", lng, ". Returning default rating."), call. = FALSE)
    return(DEFAULT_RATING)
  }
  
  # Using Text Search API to find the place first.
  # We include the name and location to be more specific.
  # Alternative: Nearby Search if the name is generic and location is key.
  search_url <- "https://maps.googleapis.com/maps/api/place/textsearch/json"
  
  query_params <- list(
    query = place_name,
    location = paste(lat, lng, sep = ","),
    radius = radius, # Radius in meters. Adjust as needed.
    key = api_key
  )
  
  tryCatch({
    res <- GET(search_url, query = query_params, timeout(10)) # 10 second timeout
    
    if (status_code(res) != 200) {
      warning(paste0("Google Places API (Text Search) request failed for '", place_name, "' with status: ", status_code(res)), call. = FALSE)
      return(DEFAULT_RATING)
    }
    
    content_res <- content(res, "text", encoding = "UTF-8")
    data_res <- fromJSON(content_res)
    
    if (data_res$status == "OK" && length(data_res$results) > 0) {
      # Assuming the first result is the most relevant.
      # For more accuracy, one might implement logic to choose the best match
      # based on distance or name similarity if multiple results are returned.
      place <- data_res$results[1, ]
      
      if (!is.null(place$rating)) {
        return(as.numeric(place$rating))
      } else {
        warning(paste0("Place '", place_name, "' (ID: ", place$place_id, ") found, but has no rating. Returning default rating."), call. = FALSE)
        return(DEFAULT_RATING)
      }
      
    } else if (data_res$status == "ZERO_RESULTS") {
      warning(paste0("Google Places API: No results found for '", place_name, "' near ", lat, ",", lng, ". Status: ", data_res$status), call. = FALSE)
      return(DEFAULT_RATING)
    } else {
      warning(paste0("Google Places API (Text Search) error for '", place_name, "'. Status: ", data_res$status, ". Message: ", data_res$error_message %||% "N/A"), call. = FALSE)
      return(DEFAULT_RATING)
    }
    
  }, error = function(e) {
    warning(paste0("Error during Google Places API call for '", place_name, "': ", e$message), call. = FALSE)
    return(DEFAULT_RATING)
  })
}

# Helper for NULL or empty string check, useful for error messages
`%||%` <- function(a, b) if (!is.null(a) && a != "") a else b

# Example Usage (for testing purposes, comment out in production):
# Sys.setenv(GOOGLE_PLACES_API_KEY = "YOUR_API_KEY_HERE") # Replace with your actual key for testing
# test_rating <- get_google_place_rating("Eiffel Tower", 48.858370, 2.294481)
# print(paste("Rating for Eiffel Tower:", test_rating))
# test_rating_no_place <- get_google_place_rating("NonExistentPlace123", 17.06, -96.72)
# print(paste("Rating for NonExistentPlace123:", test_rating_no_place))
# test_rating_no_key <- get_google_place_rating("Some Place", 17.06, -96.72, api_key = "")
# print(paste("Rating with no API key:", test_rating_no_key))