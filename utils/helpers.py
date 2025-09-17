"""
Helper functions for geographic operations and data processing
"""

import pandas as pd
import numpy as np
import geopandas as gpd
from shapely.geometry import Point
import warnings

def get_centroid_for_area(municipio_name=None, localidad_name=None, sf_data=None):
    """
    Get centroid coordinates for a specified municipality and/or locality
    
    Parameters:
    - municipio_name: Name of municipality (optional)
    - localidad_name: Name of locality (optional)  
    - sf_data: GeoDataFrame with geographic data
    
    Returns:
    - dict: Dictionary with 'lat' and 'lng' keys, or None if not found
    """
    
    if sf_data is None or not isinstance(sf_data, gpd.GeoDataFrame):
        raise ValueError("sf_data must be a GeoDataFrame")
    
    required_cols = ['nombre_municipio', 'nombre_localidad']
    if not all(col in sf_data.columns for col in required_cols):
        raise ValueError("sf_data must contain 'nombre_municipio' and 'nombre_localidad' columns")
    
    # Normalize inputs
    mun_query = None
    if municipio_name and len(str(municipio_name).strip()) > 0:
        mun_query = str(municipio_name).strip().lower()
    
    loc_query = None
    if localidad_name and len(str(localidad_name).strip()) > 0:
        loc_query = str(localidad_name).strip().lower()
    
    if mun_query is None and loc_query is None:
        return None
    
    # Filter data
    filtered_data = sf_data.copy()
    
    if mun_query is not None:
        # Case-insensitive matching for municipality
        mask = filtered_data['nombre_municipio'].astype(str).str.strip().str.lower() == mun_query
        filtered_data = filtered_data[mask]
    
    if len(filtered_data) == 0 and mun_query is not None:
        return None
    
    if loc_query is not None:
        # Case-insensitive matching for locality
        mask = filtered_data['nombre_localidad'].astype(str).str.strip().str.lower() == loc_query
        filtered_data = filtered_data[mask]
    
    if len(filtered_data) == 0:
        return None
    
    try:
        # Combine geometries if multiple rows matched
        if len(filtered_data) == 1:
            combined_geometry = filtered_data.geometry.iloc[0]
        else:
            # Union all geometries
            combined_geometry = filtered_data.geometry.unary_union
        
        # Calculate centroid
        centroid = combined_geometry.centroid
        
        # Extract coordinates
        if hasattr(centroid, 'x') and hasattr(centroid, 'y'):
            return {
                'lat': centroid.y,
                'lng': centroid.x
            }
        else:
            warnings.warn(f"Could not extract coordinates from centroid for area")
            return None
    
    except Exception as e:
        warnings.warn(f"Error calculating centroid for area: {e}")
        return None

def calculate_distance_km(lat1, lng1, lat2, lng2):
    """
    Calculate distance between two points in kilometers using Haversine formula
    
    Parameters:
    - lat1, lng1: Coordinates of first point
    - lat2, lng2: Coordinates of second point
    
    Returns:
    - float: Distance in kilometers
    """
    
    try:
        # Convert to radians
        lat1, lng1, lat2, lng2 = map(np.radians, [lat1, lng1, lat2, lng2])
        
        # Haversine formula
        dlat = lat2 - lat1
        dlng = lng2 - lng1
        
        a = np.sin(dlat/2)**2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlng/2)**2
        c = 2 * np.arcsin(np.sqrt(a))
        
        # Earth's radius in kilometers
        r = 6371
        
        return c * r
    
    except Exception as e:
        warnings.warn(f"Error calculating distance: {e}")
        return np.inf

def validate_coordinates(lat, lng):
    """
    Validate that coordinates are within reasonable bounds
    
    Parameters:
    - lat: Latitude
    - lng: Longitude
    
    Returns:
    - bool: True if coordinates are valid
    """
    
    try:
        lat_num = float(lat)
        lng_num = float(lng)
        
        # Check bounds
        if lat_num < -90 or lat_num > 90:
            return False
        
        if lng_num < -180 or lng_num > 180:
            return False
        
        return True
    
    except (ValueError, TypeError):
        return False

def normalize_column_names(df):
    """
    Normalize DataFrame column names to lowercase and replace spaces with underscores
    
    Parameters:
    - df: pandas DataFrame
    
    Returns:
    - pandas DataFrame: DataFrame with normalized column names
    """
    
    if not isinstance(df, pd.DataFrame):
        return df
    
    df_copy = df.copy()
    
    # Normalize column names
    df_copy.columns = (df_copy.columns
                      .str.lower()
                      .str.strip()
                      .str.replace(' ', '_')
                      .str.replace('-', '_')
                      .str.replace('.', '_'))
    
    return df_copy

def create_buffer_around_point(lat, lng, radius_km):
    """
    Create a circular buffer around a point
    
    Parameters:
    - lat: Latitude of center point
    - lng: Longitude of center point
    - radius_km: Radius in kilometers
    
    Returns:
    - shapely.geometry.Polygon: Buffer polygon
    """
    
    try:
        from shapely.geometry import Point
        
        # Create point
        point = Point(lng, lat)
        
        # Create buffer (approximate - uses degrees)
        # 1 degree ≈ 111 km at equator
        radius_degrees = radius_km / 111.0
        
        buffer_polygon = point.buffer(radius_degrees)
        
        return buffer_polygon
    
    except Exception as e:
        warnings.warn(f"Error creating buffer: {e}")
        return None

def filter_data_by_bounds(df, lat_col, lng_col, min_lat, max_lat, min_lng, max_lng):
    """
    Filter DataFrame by geographic bounds
    
    Parameters:
    - df: pandas DataFrame
    - lat_col: Name of latitude column
    - lng_col: Name of longitude column
    - min_lat, max_lat: Latitude bounds
    - min_lng, max_lng: Longitude bounds
    
    Returns:
    - pandas DataFrame: Filtered DataFrame
    """
    
    if not isinstance(df, pd.DataFrame):
        return df
    
    if lat_col not in df.columns or lng_col not in df.columns:
        warnings.warn(f"Columns {lat_col} or {lng_col} not found in DataFrame")
        return df
    
    try:
        mask = (
            (df[lat_col] >= min_lat) & 
            (df[lat_col] <= max_lat) &
            (df[lng_col] >= min_lng) & 
            (df[lng_col] <= max_lng)
        )
        
        return df[mask].copy()
    
    except Exception as e:
        warnings.warn(f"Error filtering data by bounds: {e}")
        return df