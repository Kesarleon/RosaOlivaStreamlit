"""
Google Places API interaction functions
"""

import requests
import warnings
from config import GOOGLE_PLACES_API_KEY

# Default rating to use when API is not available or fails
DEFAULT_RATING = 3.5

def get_google_place_rating(place_name, lat, lng):
    """
    Get Google Places rating for a business
    
    Parameters:
    - place_name: Name of the business
    - lat: Latitude of the business
    - lng: Longitude of the business
    
    Returns:
    - float: Rating from Google Places API or default rating
    """
    
    # Check if API key is available
    if not GOOGLE_PLACES_API_KEY or len(GOOGLE_PLACES_API_KEY.strip()) == 0:
        return DEFAULT_RATING
    
    try:
        # Google Places Nearby Search API
        base_url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        
        params = {
            'location': f"{lat},{lng}",
            'radius': 100,  # Small radius to find the specific place
            'name': place_name,
            'key': GOOGLE_PLACES_API_KEY
        }
        
        response = requests.get(base_url, params=params, timeout=10)
        
        if response.status_code != 200:
            warnings.warn(f"Google Places API error: {response.status_code}")
            return DEFAULT_RATING
        
        data = response.json()
        
        if data.get('status') != 'OK':
            if data.get('status') == 'ZERO_RESULTS':
                # No results found, return default
                return DEFAULT_RATING
            else:
                warnings.warn(f"Google Places API status: {data.get('status')}")
                return DEFAULT_RATING
        
        results = data.get('results', [])
        
        if len(results) == 0:
            return DEFAULT_RATING
        
        # Get rating from first result
        first_result = results[0]
        rating = first_result.get('rating', DEFAULT_RATING)
        
        # Validate rating is a number
        try:
            rating = float(rating)
            # Ensure rating is within reasonable bounds
            if rating < 1.0 or rating > 5.0:
                return DEFAULT_RATING
            return rating
        except (ValueError, TypeError):
            return DEFAULT_RATING
    
    except requests.exceptions.Timeout:
        warnings.warn("Google Places API request timed out")
        return DEFAULT_RATING
    
    except requests.exceptions.RequestException as e:
        warnings.warn(f"Error connecting to Google Places API: {e}")
        return DEFAULT_RATING
    
    except Exception as e:
        warnings.warn(f"Unexpected error in Google Places API call: {e}")
        return DEFAULT_RATING

def search_google_places(query, lat, lng, radius=1000):
    """
    Search for places using Google Places Text Search API
    
    Parameters:
    - query: Search query string
    - lat: Latitude of search center
    - lng: Longitude of search center
    - radius: Search radius in meters
    
    Returns:
    - list: List of place dictionaries
    """
    
    if not GOOGLE_PLACES_API_KEY or len(GOOGLE_PLACES_API_KEY.strip()) == 0:
        return []
    
    try:
        base_url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
        
        params = {
            'query': query,
            'location': f"{lat},{lng}",
            'radius': radius,
            'key': GOOGLE_PLACES_API_KEY
        }
        
        response = requests.get(base_url, params=params, timeout=15)
        
        if response.status_code != 200:
            warnings.warn(f"Google Places Text Search API error: {response.status_code}")
            return []
        
        data = response.json()
        
        if data.get('status') != 'OK':
            if data.get('status') != 'ZERO_RESULTS':
                warnings.warn(f"Google Places Text Search API status: {data.get('status')}")
            return []
        
        results = data.get('results', [])
        
        # Extract relevant information
        places = []
        for result in results:
            place = {
                'name': result.get('name', 'Unknown'),
                'lat': result.get('geometry', {}).get('location', {}).get('lat', 0),
                'lng': result.get('geometry', {}).get('location', {}).get('lng', 0),
                'rating': result.get('rating', DEFAULT_RATING),
                'address': result.get('formatted_address', ''),
                'types': result.get('types', [])
            }
            places.append(place)
        
        return places
    
    except Exception as e:
        warnings.warn(f"Error in Google Places text search: {e}")
        return []