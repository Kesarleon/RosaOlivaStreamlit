"""
Huff model module for market capture analysis
"""

import streamlit as st
import pandas as pd
import numpy as np
import folium
from streamlit_folium import st_folium
import plotly.express as px
from pathlib import Path
import sys

# Add utils to path
sys.path.append(str(Path(__file__).parent.parent / "utils"))

from config import APP_CONFIG, GOOGLE_PLACES_API_KEY
from huff_model import huff_model
from google_places import get_google_place_rating

def render_huff_page():
    st.header("📊 Análisis de Captación - Modelo Huff")
    
    if not GOOGLE_PLACES_API_KEY:
        st.warning("⚠️ GOOGLE_PLACES_API_KEY no configurada. Atractividad de competencia usará valores por defecto.")
    
    # Check if we have map data
    map_data = st.session_state.get('map_data', {})
    
    col1, col2 = st.columns([1, 2])
    
    with col1:
        st.subheader("Configuración")
        
        # Sucursal selection
        if map_data.get('clicked_sucursal'):
            st.info("🎯 Usando ubicación seleccionada en el mapa")
            sucursal_nombre = "Sucursal Oportunidad"
            sucursales_data = pd.DataFrame({
                'id': ['clicked'],
                'nombre': ['Sucursal Oportunidad'],
                'atractivo': [100],
                'lat': [map_data['clicked_sucursal']['lat']],
                'lng': [map_data['clicked_sucursal']['lng']]
            })
        else:
            st.info("📍 Usando sucursales predefinidas")
            sucursales_data = APP_CONFIG['sucursales_rosa_data']
            sucursal_nombre = st.selectbox(
                "Sucursal Rosa Oliva:",
                sucursales_data['nombre'].tolist()
            )
        
        # Model parameters
        st.subheader("Parámetros del modelo")
        alfa = st.number_input(
            "Atractivo (α):",
            value=float(APP_CONFIG['huff_default_alfa']),
            min_value=0.1,
            max_value=3.0,
            step=0.1
        )
        
        beta = st.number_input(
            "Fricción distancia (β):",
            value=float(APP_CONFIG['huff_default_beta']),
            min_value=0.1,
            max_value=5.0,
            step=0.1
        )
        
        # Calculate button
        calcular = st.button("🔄 Calcular captación", type="primary")
    
    with col2:
        st.subheader("Resultados de captación")
        
        if calcular:
            with st.spinner("Calculando captación..."):
                resultados = calculate_huff_model(
                    sucursal_nombre, 
                    sucursales_data,
                    map_data,
                    alfa, 
                    beta
                )
                
                if resultados is not None and len(resultados) > 0:
                    # Display results table
                    display_cols = ['Negocio', 'Tipo', 'Captación estimada', 'Participación (%)', 'AGEBs influencia']
                    st.dataframe(
                        resultados[display_cols],
                        use_container_width=True,
                        hide_index=True
                    )
                    
                    # Store results for map
                    st.session_state.huff_results = resultados
                    st.session_state.selected_sucursal = sucursal_nombre
                else:
                    st.error("Error en el cálculo del modelo Huff")
        
        # Display map if we have results
        if hasattr(st.session_state, 'huff_results'):
            st.subheader("Mapa de análisis")
            huff_map = create_huff_map()
            st_folium(huff_map, width=700, height=400)

def calculate_huff_model(sucursal_nombre, sucursales_data, map_data, alfa, beta):
    """Calculate Huff model results"""
    
    try:
        # Get selected sucursal
        suc_sel = sucursales_data[sucursales_data['nombre'] == sucursal_nombre]
        if len(suc_sel) == 0:
            st.error("Sucursal seleccionada no encontrada")
            return None
        
        # Get competition data
        if map_data.get('competencia') is not None and len(map_data['competencia']) > 0:
            comp_data = map_data['competencia'].copy()
        else:
            comp_data = APP_CONFIG['competencia_base_data'].copy()
        
        # Add attractiveness to competition
        comp_data['atractivo'] = 3.5  # Default rating
        
        for idx, row in comp_data.iterrows():
            if GOOGLE_PLACES_API_KEY:
                rating = get_google_place_rating(
                    row['nombre'],
                    row['lat'] if 'lat' in row else row['latitud'],
                    row['lng'] if 'lng' in row else row['longitud']
                )
                comp_data.loc[idx, 'atractivo'] = rating
        
        # Combine all points
        suc_sel_copy = suc_sel.copy()
        suc_sel_copy['tipo'] = 'Rosa Oliva'
        
        comp_data_copy = comp_data.copy()
        comp_data_copy['tipo'] = 'Competencia'
        
        # Standardize column names
        if 'latitud' in comp_data_copy.columns:
            comp_data_copy = comp_data_copy.rename(columns={'latitud': 'lat', 'longitud': 'lng'})
        
        todos_puntos = pd.concat([suc_sel_copy, comp_data_copy], ignore_index=True)
        
        # Get AGEB data
        agebs_hex = st.session_state.agebs_hex
        
        # Calculate centroids for AGEBs
        agebs_data = []
        for idx, row in agebs_hex.iterrows():
            if pd.notna(row['geometry']):
                centroid = row['geometry'].centroid
                agebs_data.append({
                    'cvegeo': row.get('id_hex', f'ageb_{idx}'),
                    'lat': centroid.y,
                    'lng': centroid.x,
                    'poblacion': row.get('clientes_totales', 100)
                })
        
        agebs_df = pd.DataFrame(agebs_data)
        
        if len(agebs_df) == 0:
            st.error("No hay datos de AGEBs disponibles")
            return None
        
        # Calculate Huff model for each AGEB
        resultados_detalle = []
        
        for _, ageb in agebs_df.iterrows():
            res_huff = huff_model(
                ag_lat=ageb['lat'],
                ag_lng=ageb['lng'],
                puntos=todos_puntos,
                alfa=alfa,
                beta=beta
            )
            
            for _, punto in res_huff.iterrows():
                resultados_detalle.append({
                    'cvegeo': ageb['cvegeo'],
                    'poblacion': ageb['poblacion'],
                    'agebs_lat': ageb['lat'],
                    'agebs_lng': ageb['lng'],
                    'id': punto['id'],
                    'nombre': punto['nombre'],
                    'tipo': punto['tipo'],
                    'prob': punto['prob'],
                    'distancia': punto['distancia'],
                    'utilidad': punto['utilidad']
                })
        
        resultados_df = pd.DataFrame(resultados_detalle)
        
        # Calculate summary
        total_poblacion = agebs_df['poblacion'].sum()
        
        captacion_resumen = resultados_df.groupby(['id', 'nombre', 'tipo']).agg({
            'prob': lambda x: (x * resultados_df.loc[x.index, 'poblacion']).sum(),
            'cvegeo': lambda x: len(x[resultados_df.loc[x.index, 'prob'] > 0.1])
        }).reset_index()
        
        captacion_resumen.columns = ['id', 'nombre', 'tipo', 'captacion_total', 'agebs_influencia']
        captacion_resumen['participacion'] = (captacion_resumen['captacion_total'] / total_poblacion * 100).round(2)
        
        # Rename columns for display
        captacion_resumen = captacion_resumen.rename(columns={
            'nombre': 'Negocio',
            'tipo': 'Tipo',
            'captacion_total': 'Captación estimada',
            'participacion': 'Participación (%)',
            'agebs_influencia': 'AGEBs influencia'
        })
        
        captacion_resumen = captacion_resumen.sort_values('Captación estimada', ascending=False)
        
        # Store detailed results for mapping
        st.session_state.huff_detailed = resultados_df
        
        return captacion_resumen
        
    except Exception as e:
        st.error(f"Error en cálculo: {e}")
        return None

def create_huff_map():
    """Create map showing Huff model results"""
    
    # Create base map
    m = folium.Map(
        location=[APP_CONFIG['default_lat'], APP_CONFIG['default_lng']],
        zoom_start=13,
        tiles='CartoDB positron'
    )
    
    if not hasattr(st.session_state, 'huff_detailed'):
        return m
    
    detailed_results = st.session_state.huff_detailed
    selected_sucursal = st.session_state.get('selected_sucursal', '')
    
    # Filter for selected sucursal
    sucursal_results = detailed_results[
        (detailed_results['nombre'] == selected_sucursal) & 
        (detailed_results['tipo'] == 'Rosa Oliva')
    ]
    
    if len(sucursal_results) == 0:
        return m
    
    # Add AGEB circles colored by probability
    max_prob = sucursal_results['prob'].max() if len(sucursal_results) > 0 else 1
    
    for _, row in sucursal_results.iterrows():
        prob = row['prob']
        color_intensity = prob / max_prob if max_prob > 0 else 0
        
        # Color from light red to dark red
        color = f"#{int(255 - 100 * color_intensity):02x}{int(100 + 100 * color_intensity):02x}{int(100):02x}"
        
        folium.CircleMarker(
            location=[row['agebs_lat'], row['agebs_lng']],
            radius=max(3, min(12, np.sqrt(row['poblacion']) / 10)),
            color=color,
            fillColor=color,
            fillOpacity=0.6,
            popup=f"""
            <b>AGEB:</b> {row['cvegeo']}<br>
            <b>Población:</b> {row['poblacion']:.0f}<br>
            <b>Prob. captación:</b> {prob:.1%}
            """
        ).add_to(m)
    
    # Add store markers
    map_data = st.session_state.get('map_data', {})
    
    # Add Rosa Oliva stores
    if map_data.get('clicked_sucursal'):
        folium.Marker(
            location=[map_data['clicked_sucursal']['lat'], map_data['clicked_sucursal']['lng']],
            popup="Sucursal Oportunidad",
            icon=folium.Icon(color='green', icon='store')
        ).add_to(m)
    else:
        for _, store in APP_CONFIG['sucursales_rosa_data'].iterrows():
            folium.Marker(
                location=[store['lat'], store['lng']],
                popup=f"<b>{store['nombre']}</b><br>Atractivo: {store['atractivo']}",
                icon=folium.Icon(color='green', icon='store')
            ).add_to(m)
    
    # Add competition markers
    if map_data.get('competencia') is not None:
        for _, comp in map_data['competencia'].iterrows():
            lat_col = 'lat' if 'lat' in comp else 'latitud'
            lng_col = 'lng' if 'lng' in comp else 'longitud'
            
            folium.Marker(
                location=[comp[lat_col], comp[lng_col]],
                popup=f"<b>{comp['nombre']}</b><br>Competencia",
                icon=folium.Icon(color='black', icon='store')
            ).add_to(m)
    else:
        for _, comp in APP_CONFIG['competencia_base_data'].iterrows():
            folium.Marker(
                location=[comp['lat'], comp['lng']],
                popup=f"<b>{comp['nombre']}</b><br>Competencia",
                icon=folium.Icon(color='black', icon='store')
            ).add_to(m)
    
    return m