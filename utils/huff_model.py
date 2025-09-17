"""
Huff Model implementation for market capture analysis
"""

import pandas as pd
import numpy as np
from geopy.distance import geodesic
import warnings

def huff_model(ag_lat, ag_lng, puntos, alfa=1, beta=3):
    """
    Calculate capture probability using Huff Model
    
    Parameters:
    - ag_lat, ag_lng: Latitude and longitude of demand point (e.g., AGEB centroid)
    - puntos: DataFrame with columns 'lat', 'lng', 'id', 'atractivo' (attractiveness)
    - alfa: Attractiveness sensitivity parameter (default=1)
    - beta: Distance friction parameter (default=3)
    
    Returns:
    - DataFrame with original data plus 'distancia', 'utilidad', 'prob' columns
    """
    
    try:
        # Input validation
        if not isinstance(ag_lat, (int, float)) or not isinstance(ag_lng, (int, float)):
            raise ValueError("Demand point coordinates must be numeric")
        
        if not isinstance(puntos, pd.DataFrame):
            raise ValueError("Points must be a pandas DataFrame")
        
        required_cols = ['lat', 'lng', 'atractivo']
        if not all(col in puntos.columns for col in required_cols):
            raise ValueError(f"Points DataFrame must contain columns: {required_cols}")
        
        if len(puntos) == 0:
            # Return empty DataFrame with expected columns
            result = puntos.copy()
            result['distancia'] = []
            result['utilidad'] = []
            result['prob'] = []
            return result
        
        # Validate numeric columns
        for col in required_cols:
            if not pd.api.types.is_numeric_dtype(puntos[col]):
                raise ValueError(f"Column '{col}' must be numeric")
        
        result = puntos.copy()
        
        # Calculate distances using geodesic (more accurate than Euclidean)
        distances = []
        for _, punto in puntos.iterrows():
            try:
                dist = geodesic((ag_lat, ag_lng), (punto['lat'], punto['lng'])).kilometers
                distances.append(dist)
            except Exception as e:
                warnings.warn(f"Error calculating distance for point {punto.get('id', 'unknown')}: {e}")
                distances.append(np.inf)
        
        result['distancia'] = distances
        
        # Avoid division by zero - set minimum distance
        result['distancia'] = result['distancia'].replace(0, 0.001)
        
        # Calculate utility with alfa and beta parameters
        # Ensure attractiveness is positive for non-integer alfa
        result['atractivo'] = result['atractivo'].clip(lower=0.001)
        result['utilidad'] = (result['atractivo'] ** alfa) / (result['distancia'] ** beta)
        
        # Calculate probabilities
        total_utilidad = result['utilidad'].sum()
        
        if total_utilidad > 0:
            result['prob'] = result['utilidad'] / total_utilidad
        else:
            # If total utility is 0, assign equal probability to all points
            if len(result) > 0:
                result['prob'] = 1.0 / len(result)
            else:
                result['prob'] = 0.0
        
        return result
        
    except Exception as e:
        warnings.warn(f"Error in huff_model: {e}")
        # Return original DataFrame with error columns
        result = puntos.copy()
        result['distancia'] = np.inf
        result['utilidad'] = 0.0
        result['prob'] = 0.0
        return result