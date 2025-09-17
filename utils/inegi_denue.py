"""
INEGI DENUE API interaction functions
"""

import requests
import pandas as pd
import warnings
from urllib.parse import quote

def esta_en_mexico(lat, lon):
    """
    Check if coordinates are within Mexico's approximate boundaries
    
    Parameters:
    - lat: Latitude
    - lon: Longitude
    
    Returns:
    - bool: True if coordinates are within Mexico
    """
    try:
        lat_num = float(lat)
        lon_num = float(lon)
    except (ValueError, TypeError):
        return False
    
    # Approximate Mexico boundaries
    if (lat_num < 14.559507 or lat_num > 32.757120 or
        lon_num > -86.708301 or lon_num < -118.312155):
        return False
    
    return True

def inegi_denue(latitud, longitud, token, meters=250, keyword="todos", timeout_sec=60):
    """
    Query INEGI DENUE API for nearby businesses
    
    Parameters:
    - latitud: Latitude of search center
    - longitud: Longitude of search center  
    - token: INEGI API token
    - meters: Search radius in meters (default=250)
    - keyword: Search keyword (default="todos")
    - timeout_sec: Request timeout in seconds (default=60)
    
    Returns:
    - pandas.DataFrame: Business data with standardized column names
    """
    
    # Validate token
    if not token or not isinstance(token, str) or len(token.strip()) == 0:
        warnings.warn("INEGI API token not provided or empty. Cannot perform query.")
        return pd.DataFrame()
    
    # Check if coordinates are within Mexico
    if not esta_en_mexico(latitud, longitud):
        warnings.warn("Provided coordinates are outside Mexico. Query will not be performed.")
        return pd.DataFrame()
    
    # Build API URL
    base_url = "https://www.inegi.org.mx/app/api/denue/v1/consulta/Buscar/"
    
    # URL encode the keyword to handle special characters
    keyword_encoded = quote(keyword)
    
    consulta_url = f"{base_url}{keyword_encoded}/{latitud},{longitud}/{meters}/{token}"
    
    try:
        # Make request with timeout
        response = requests.get(consulta_url, timeout=timeout_sec)
        
        # Check HTTP status code
        if response.status_code != 200:
            error_content = response.text
            warnings.warn(
                f"DENUE API responded with code: {response.status_code}. Message: {error_content}"
            )
            return pd.DataFrame()
        
        # Get response content
        response_text = response.text
        
        if not response_text or len(response_text.strip()) == 0:
            return pd.DataFrame()
        
        # Parse JSON response
        try:
            import json
            data = json.loads(response_text)
            
            if not data or len(data) == 0:
                return pd.DataFrame()
            
            # Convert to DataFrame
            df = pd.DataFrame(data)
            
            # Standardize column names to lowercase
            if len(df) > 0:
                df.columns = df.columns.str.lower()
            
            return df
            
        except json.JSONDecodeError as e:
            warnings.warn(f"Could not parse JSON response from DENUE: {e}")
            return pd.DataFrame()
    
    except requests.exceptions.Timeout:
        warnings.warn("Request to DENUE API timed out")
        return pd.DataFrame()
    
    except requests.exceptions.RequestException as e:
        warnings.warn(f"Error connecting to DENUE API: {e}")
        return pd.DataFrame()
    
    except Exception as e:
        warnings.warn(f"Unexpected error during DENUE query: {e}")
        return pd.DataFrame()