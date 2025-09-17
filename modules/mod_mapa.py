"""
Mapa module with hexagonal visualization, location search, and business search
"""

import streamlit as st
import folium
from streamlit_folium import st_folium
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from pathlib import Path
import sys

# Add utils to path
sys.path.append(str(Path(__file__).parent.parent / "utils"))

from config import APP_CONFIG, INEGI_API_KEY
from inegi_denue import inegi_denue
from helpers import get_centroid_for_area

def render_mapa_page():
    st.header("🗺️ Mapa Principal")
    
    # Initialize session state for map
    if 'centro_lat' not in st.session_state:
        st.session_state.centro_lat = APP_CONFIG['default_lat']
        st.session_state.centro_lng = APP_CONFIG['default_lng']
    
    if 'negocios_data' not in st.session_state:
        st.session_state.negocios_data = pd.DataFrame()
    
    if 'clicked_coordinates' not in st.session_state:
        st.session_state.clicked_coordinates = None
    
    # Main layout
    col1, col2 = st.columns([2, 1])
    
    with col1:
        # Map controls
        st.subheader("Controles del Mapa")
        
        col_ctrl1, col_ctrl2 = st.columns(2)
        
        with col_ctrl1:
            # Location controls
            estado = st.text_input("Estado:", value="Oaxaca")
            
            # Get unique municipalities and localities
            agebs_hex = st.session_state.agebs_hex
            if 'nombre_municipio' in agebs_hex.columns:
                municipios = sorted(agebs_hex['nombre_municipio'].dropna().unique())
                municipio = st.selectbox("Municipio:", [""] + municipios)
                
                if municipio:
                    localidades = sorted(agebs_hex[agebs_hex['nombre_municipio'] == municipio]['nombre_localidad'].dropna().unique())
                else:
                    localidades = sorted(agebs_hex['nombre_localidad'].dropna().unique())
                
                localidad = st.selectbox("Localidad:", [""] + localidades)
            else:
                municipio = st.text_input("Municipio:")
                localidad = st.text_input("Localidad:")
            
            if st.button("Centrar mapa"):
                if municipio or localidad:
                    coords = get_centroid_for_area(municipio, localidad, agebs_hex)
                    if coords:
                        st.session_state.centro_lat = coords['lat']
                        st.session_state.centro_lng = coords['lng']
                        st.session_state.clicked_coordinates = coords
                        st.success(f"Mapa centrado en: {municipio}, {localidad}")
                        st.rerun()
                    else:
                        st.warning("No se pudo encontrar la ubicación especificada")
                else:
                    st.warning("Ingrese un municipio y/o localidad")
        
        with col_ctrl2:
            # Business search controls
            palabra_clave = st.text_input(
                "Palabra clave:", 
                value=APP_CONFIG['map_search_keyword_default']
            )
            radio = st.number_input(
                "Radio de búsqueda (m):", 
                value=APP_CONFIG['map_search_radius_default'],
                min_value=100, 
                step=100
            )
            
            if st.button("Buscar negocios"):
                search_coords = None
                
                if st.session_state.clicked_coordinates:
                    search_coords = st.session_state.clicked_coordinates
                    source_msg = "punto seleccionado"
                else:
                    search_coords = {
                        'lat': st.session_state.centro_lat,
                        'lng': st.session_state.centro_lng
                    }
                    source_msg = "centro del mapa"
                
                if search_coords:
                    with st.spinner(f"Buscando negocios en {source_msg}..."):
                        negocios = search_businesses(
                            search_coords['lat'], 
                            search_coords['lng'],
                            palabra_clave, 
                            radio
                        )
                        st.session_state.negocios_data = negocios
                        
                        if len(negocios) > 0:
                            st.success(f"Se encontraron {len(negocios)} negocios")
                        else:
                            st.warning("No se encontraron negocios")
        
        # Map display options
        mostrar_hexbin = st.checkbox("Mostrar hexágonos", value=True)
        
        # Reset button
        if st.button("Borrar marcadores y centrar mapa"):
            st.session_state.negocios_data = pd.DataFrame()
            st.session_state.clicked_coordinates = None
            st.session_state.centro_lat = APP_CONFIG['default_lat']
            st.session_state.centro_lng = APP_CONFIG['default_lng']
            st.rerun()
        
        # Create and display map
        m = create_map(mostrar_hexbin)
        map_data = st_folium(m, width=700, height=500, returned_objects=["last_clicked"])
        
        # Handle map clicks
        if map_data['last_clicked']:
            clicked_lat = map_data['last_clicked']['lat']
            clicked_lng = map_data['last_clicked']['lng']
            
            st.session_state.clicked_coordinates = {
                'lat': clicked_lat, 
                'lng': clicked_lng
            }
            st.session_state.centro_lat = clicked_lat
            st.session_state.centro_lng = clicked_lng
            
            # Update map_data for Huff model
            st.session_state.map_data['clicked_sucursal'] = {
                'lat': clicked_lat,
                'lng': clicked_lng
            }
            
            # Find nearby competition
            if INEGI_API_KEY:
                negocios = search_businesses(clicked_lat, clicked_lng, "todos", 500)
                if len(negocios) > 0:
                    # Get 5 nearest businesses
                    negocios['distancia'] = np.sqrt(
                        (negocios['latitud'] - clicked_lat)**2 + 
                        (negocios['longitud'] - clicked_lng)**2
                    )
                    competencia = negocios.nsmallest(5, 'distancia')
                    st.session_state.map_data['competencia'] = competencia
            
            st.info("Punto seleccionado en el mapa. Use 'Buscar negocios' para encontrar negocios aquí.")
    
    with col2:
        # Variable selection and histogram
        st.subheader("Perfil del Cliente")
        
        variable_options = {
            "Joven Digital": "joven_digital",
            "Mamá Emprendedora": "mama_emprendedora", 
            "Mayorista Experimentado": "mayorista_experimentado",
            "Cliente Potencial": "clientes_totales"
        }
        
        selected_var_name = st.selectbox(
            "Seleccionar perfil:",
            list(variable_options.keys()),
            index=3  # Default to "Cliente Potencial"
        )
        
        selected_var = variable_options[selected_var_name]
        
        # Create histogram
        agebs_hex = st.session_state.agebs_hex
        if selected_var in agebs_hex.columns:
            variable_data = agebs_hex[selected_var].dropna()
            
            if len(variable_data) > 0:
                fig = px.histogram(
                    x=variable_data,
                    nbins=20,
                    title=f"Distribución de: {selected_var_name}",
                    labels={'x': selected_var_name.replace('_', ' '), 'y': 'Frecuencia'}
                )
                fig.update_traces(marker_color='#7A9E7E')
                fig.update_layout(height=400)
                st.plotly_chart(fig, use_container_width=True)
            else:
                st.warning("No hay datos disponibles para el histograma")
        else:
            st.warning("Variable no disponible en los datos")

def create_map(mostrar_hexbin=True):
    """Create the folium map with hexagons and markers"""
    
    # Create base map
    m = folium.Map(
        location=[st.session_state.centro_lat, st.session_state.centro_lng],
        zoom_start=13,
        tiles='CartoDB positron'
    )
    
    # Add hexagonal grid if enabled
    if mostrar_hexbin:
        agebs_hex = st.session_state.agebs_hex
        
        # Get selected variable for coloring
        variable_options = {
            "Joven Digital": "joven_digital",
            "Mamá Emprendedora": "mama_emprendedora",
            "Mayorista Experimentado": "mayorista_experimentado", 
            "Cliente Potencial": "clientes_totales"
        }
        
        # Default to clientes_totales if not in session state
        selected_var = getattr(st.session_state, 'selected_variable', 'clientes_totales')
        
        if selected_var in agebs_hex.columns:
            # Add hexagons with color coding
            for idx, row in agebs_hex.iterrows():
                if pd.notna(row['geometry']):
                    # Convert geometry to coordinates
                    coords = []
                    if hasattr(row['geometry'], 'exterior'):
                        coords = [[lat, lng] for lng, lat in row['geometry'].exterior.coords]
                    
                    if coords:
                        # Color based on variable value
                        value = row[selected_var] if pd.notna(row[selected_var]) else 0
                        color_intensity = min(value / agebs_hex[selected_var].max() if agebs_hex[selected_var].max() > 0 else 0, 1)
                        color = f"rgba(122, 158, 126, {0.3 + 0.4 * color_intensity})"
                        
                        folium.Polygon(
                            locations=coords,
                            color='white',
                            weight=1,
                            fillColor=f"#{int(122 + 50 * color_intensity):02x}{int(158 + 50 * color_intensity):02x}{int(126 + 50 * color_intensity):02x}",
                            fillOpacity=0.6,
                            popup=f"""
                            <b>ID Hex:</b> {row.get('id_hex', 'N/A')}<br>
                            <b>Población Total:</b> {row.get('poblacion_total', 'N/A')}<br>
                            <b>{selected_var}:</b> {value:.2f}
                            """
                        ).add_to(m)
    
    # Add business markers
    if len(st.session_state.negocios_data) > 0:
        for idx, negocio in st.session_state.negocios_data.iterrows():
            folium.Marker(
                location=[negocio['latitud'], negocio['longitud']],
                popup=negocio['nombre'],
                icon=folium.Icon(color='blue', icon='info-sign')
            ).add_to(m)
    
    # Add clicked point marker
    if st.session_state.clicked_coordinates:
        folium.Marker(
            location=[
                st.session_state.clicked_coordinates['lat'],
                st.session_state.clicked_coordinates['lng']
            ],
            popup="Punto seleccionado",
            icon=folium.Icon(color='red', icon='map-marker')
        ).add_to(m)
    
    return m

def search_businesses(lat, lng, keyword, radius):
    """Search for businesses using INEGI API or return simulated data"""
    
    if not INEGI_API_KEY:
        # Return simulated data
        n_negocios = np.random.randint(5, 15)
        return pd.DataFrame({
            'nombre': [f'Negocio Simulado {i+1}' for i in range(n_negocios)],
            'latitud': lat + np.random.uniform(-0.005, 0.005, n_negocios),
            'longitud': lng + np.random.uniform(-0.005, 0.005, n_negocios)
        })
    
    try:
        # Use real INEGI API
        negocios = inegi_denue(
            latitud=lat,
            longitud=lng,
            token=INEGI_API_KEY,
            meters=radius,
            keyword=keyword
        )
        return negocios
    except Exception as e:
        st.error(f"Error buscando negocios: {e}")
        return pd.DataFrame()