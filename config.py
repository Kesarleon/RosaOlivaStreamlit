"""
Global configuration and data loading for Rosa Oliva Geoespacial app
"""

import os
import pandas as pd
import geopandas as gpd
import numpy as np
from pathlib import Path
from shapely.geometry import Point, Polygon
import warnings

# Application Configuration
APP_CONFIG = {
    'default_lat': 17.0594,
    'default_lng': -96.7216,
    'oaxaca_grid_filepath': "data/Oaxaca_grid/oaxaca_ZMO_grid.shp",
    'huff_default_alfa': 1,
    'huff_default_beta': 3,
    'map_search_radius_default': 1000,
    'map_search_keyword_default': "joyeria",
    'socio_search_keyword_default': "joyeria",
    'sucursales_rosa_data': pd.DataFrame({
        'id': ['A', 'B', 'C'],
        'nombre': ['Sucursal Violetas', 'Sucursal Poniente', 'Sucursal Sur'],
        'lat': [17.078904, 17.07, 17.05],
        'lng': [-96.710641, -96.73, -96.71],
        'atractivo': [4.0, 4.0, 4.2]
    }),
    'competencia_base_data': pd.DataFrame({
        'id': ['X', 'Y', 'Z'],
        'nombre': ['Joyería Nice', 'Joyería Sublime', 'Joyería Ag 925'],
        'lat': [17.078891, 17.078206, 17.080318],
        'lng': [-96.710177, -96.710654, -96.713559]
    })
}

def create_hexagon(center_lat, center_lng, radius=0.002):
    """Create a hexagonal polygon around a center point"""
    angles = np.linspace(0, 2 * np.pi, 7)
    coords = [(center_lng + radius * np.cos(angle), 
               center_lat + radius * np.sin(angle)) for angle in angles]
    return Polygon(coords)

def load_global_data():
    """Load or generate hexagonal grid data"""
    
    # Try to load real data
    grid_path = Path(APP_CONFIG['oaxaca_grid_filepath'])
    
    if grid_path.exists():
        try:
            agebs_hex = gpd.read_file(grid_path)
            
            # Check and add missing columns
            if 'NOM_MUN' not in agebs_hex.columns:
                warnings.warn("Column 'NOM_MUN' not found. Adding placeholder.")
                agebs_hex['NOM_MUN'] = 'Desconocido'
            
            if 'NOM_LOC' not in agebs_hex.columns:
                warnings.warn("Column 'NOM_LOC' not found. Adding placeholder.")
                agebs_hex['NOM_LOC'] = 'Desconocida'
            
            # Standardize column names
            agebs_hex = agebs_hex.rename(columns={
                'id_hx_x': 'id_hex',
                'pblcn_t': 'poblacion_total',
                'jvn_dgt': 'joven_digital_raw',
                'mm_mprn': 'mama_emprendedora_raw',
                'myrst_x': 'mayorista_experimentado_raw',
                'cts_ttl': 'clientes_totales_raw',
                'NOM_MUN': 'nombre_municipio',
                'NOM_LOC': 'nombre_localidad'
            })
            
            # Apply log transformations
            for col in ['joven_digital_raw', 'mama_emprendedora_raw', 
                       'mayorista_experimentado_raw', 'clientes_totales_raw']:
                if col in agebs_hex.columns:
                    new_col = col.replace('_raw', '')
                    agebs_hex[new_col] = np.log1p(agebs_hex[col].fillna(0))
            
            # Select final columns
            final_cols = ['id_hex', 'poblacion_total', 'joven_digital', 
                         'mama_emprendedora', 'mayorista_experimentado', 
                         'clientes_totales', 'nombre_municipio', 'nombre_localidad', 'geometry']
            
            available_cols = [col for col in final_cols if col in agebs_hex.columns]
            agebs_hex = agebs_hex[available_cols]
            
            print(f"Successfully loaded real hexagonal grid data from: {grid_path}")
            return agebs_hex
            
        except Exception as e:
            warnings.warn(f"Error loading real data: {e}. Using simulated data.")
    
    # Generate simulated data
    warnings.warn(f"Real data not found at '{grid_path}'. Using simulated hexagonal grid data.")
    
    n_hex = 50
    np.random.seed(42)  # For reproducible results
    
    # Generate random coordinates around Oaxaca
    lats = np.random.uniform(17.04, 17.11, n_hex)
    lngs = np.random.uniform(-96.75, -96.69, n_hex)
    
    # Create hexagonal geometries
    geometries = [create_hexagon(lat, lng) for lat, lng in zip(lats, lngs)]
    
    # Create GeoDataFrame
    agebs_hex = gpd.GeoDataFrame({
        'id_hex': [f'sim_hex_{i+1}' for i in range(n_hex)],
        'poblacion_total': np.random.randint(100, 1000, n_hex),
        'joven_digital': np.log1p(np.random.randint(0, 500, n_hex)),
        'mama_emprendedora': np.log1p(np.random.randint(0, 500, n_hex)),
        'mayorista_experimentado': np.log1p(np.random.randint(0, 500, n_hex)),
        'clientes_totales': np.log1p(np.random.randint(0, 2000, n_hex)),
        'nombre_municipio': np.random.choice(['Oaxaca de Juárez', 'Santa Cruz Xoxocotlán'], n_hex),
        'nombre_localidad': np.random.choice(['Centro', 'Reforma', 'Xoxocotlán'], n_hex),
        'geometry': geometries
    }, crs='EPSG:4326')
    
    print("Generated simulated hexagonal grid data.")
    return agebs_hex

# API Keys from environment variables
GOOGLE_PLACES_API_KEY = os.getenv("GOOGLE_PLACES_API_KEY", "")
INEGI_API_KEY = os.getenv("INEGI_API_KEY", "")