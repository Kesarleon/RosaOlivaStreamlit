"""
Rosa Oliva Geoespacial - Demo Version for Streamlit Cloud
Simplified version with mock data for demonstration purposes.
"""

import streamlit as st
import pandas as pd
import numpy as np
import folium
from streamlit_folium import st_folium
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime
import json

# Demo configuration
DEMO_CONFIG = {
    'default_lat': 17.0594,
    'default_lng': -96.7216,
    'app_title': "Rosa Oliva Geoespacial - Demo",
    'app_subtitle': "Análisis estratégico para expansión de joyería"
}

# Mock data for demo
@st.cache_data
def load_demo_data():
    """Load mock data for demonstration"""
    np.random.seed(42)
    
    # Mock store locations
    sucursales = pd.DataFrame({
        'id': ['A', 'B', 'C'],
        'nombre': ['Sucursal Violetas', 'Sucursal Poniente', 'Sucursal Sur'],
        'lat': [17.078904, 17.07, 17.05],
        'lng': [-96.710641, -96.73, -96.71],
        'atractivo': [4.0, 4.0, 4.2],
        'ventas_mensuales': [150000, 120000, 180000]
    })
    
    # Mock competition data
    competencia = pd.DataFrame({
        'id': ['X', 'Y', 'Z', 'W'],
        'nombre': ['Joyería Nice', 'Joyería Sublime', 'Joyería Ag 925', 'Oro y Plata'],
        'lat': [17.078891, 17.078206, 17.080318, 17.065],
        'lng': [-96.710177, -96.710654, -96.713559, -96.720],
        'rating': [4.2, 3.8, 4.5, 4.0]
    })
    
    # Mock demographic data
    n_areas = 30
    demograficos = pd.DataFrame({
        'area_id': [f'area_{i+1}' for i in range(n_areas)],
        'lat': np.random.uniform(17.04, 17.11, n_areas),
        'lng': np.random.uniform(-96.75, -96.69, n_areas),
        'poblacion_total': np.random.randint(500, 3000, n_areas),
        'joven_digital': np.random.randint(50, 800, n_areas),
        'mama_emprendedora': np.random.randint(30, 600, n_areas),
        'mayorista_experimentado': np.random.randint(20, 400, n_areas),
        'ingreso_promedio': np.random.randint(8000, 25000, n_areas)
    })
    
    return sucursales, competencia, demograficos

def create_base_map(center_lat=17.0594, center_lng=-96.7216, zoom=12):
    """Create base folium map"""
    m = folium.Map(
        location=[center_lat, center_lng],
        zoom_start=zoom,
        tiles='OpenStreetMap'
    )
    return m

def render_mapa_demo():
    """Render the map demo page"""
    st.header("🗺️ Mapa Interactivo - Demo")
    st.write("Visualización de sucursales Rosa Oliva y competencia en Oaxaca")
    
    sucursales, competencia, demograficos = load_demo_data()
    
    # Create map
    m = create_base_map()
    
    # Add Rosa Oliva stores
    for _, store in sucursales.iterrows():
        folium.Marker(
            [store['lat'], store['lng']],
            popup=f"<b>{store['nombre']}</b><br>Ventas: ${store['ventas_mensuales']:,}",
            tooltip=store['nombre'],
            icon=folium.Icon(color='red', icon='star')
        ).add_to(m)
    
    # Add competition
    for _, comp in competencia.iterrows():
        folium.Marker(
            [comp['lat'], comp['lng']],
            popup=f"<b>{comp['nombre']}</b><br>Rating: {comp['rating']}/5",
            tooltip=comp['nombre'],
            icon=folium.Icon(color='blue', icon='info-sign')
        ).add_to(m)
    
    # Display map
    map_data = st_folium(m, width=700, height=500)
    
    # Show store information
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Sucursales Rosa Oliva")
        st.dataframe(sucursales[['nombre', 'atractivo', 'ventas_mensuales']])
    
    with col2:
        st.subheader("Competencia")
        st.dataframe(competencia[['nombre', 'rating']])

def render_huff_demo():
    """Render the Huff model demo page"""
    st.header("📊 Análisis de Captación - Demo")
    st.write("Modelo de Huff para análisis de captación de clientes")
    
    sucursales, competencia, demograficos = load_demo_data()
    
    # Parameters
    col1, col2 = st.columns(2)
    with col1:
        alfa = st.slider("Parámetro Alfa (Atractivo)", 0.5, 3.0, 1.0, 0.1)
    with col2:
        beta = st.slider("Parámetro Beta (Distancia)", 1.0, 5.0, 2.0, 0.1)
    
    # Mock Huff analysis results
    np.random.seed(42)
    huff_results = pd.DataFrame({
        'sucursal': sucursales['nombre'].tolist(),
        'captacion_estimada': np.random.uniform(0.2, 0.4, len(sucursales)),
        'clientes_potenciales': np.random.randint(800, 2000, len(sucursales))
    })
    
    # Visualization
    fig = px.bar(
        huff_results, 
        x='sucursal', 
        y='captacion_estimada',
        title='Probabilidad de Captación por Sucursal',
        color='captacion_estimada',
        color_continuous_scale='viridis'
    )
    st.plotly_chart(fig, use_container_width=True)
    
    # Results table
    st.subheader("Resultados del Análisis")
    st.dataframe(huff_results)
    
    # Market share pie chart
    fig_pie = px.pie(
        huff_results, 
        values='clientes_potenciales', 
        names='sucursal',
        title='Distribución de Clientes Potenciales'
    )
    st.plotly_chart(fig_pie, use_container_width=True)

def render_socio_demo():
    """Render the socioeconomic demo page"""
    st.header("👥 Análisis Socioeconómico - Demo")
    st.write("Perfiles de clientes y análisis demográfico")
    
    sucursales, competencia, demograficos = load_demo_data()
    
    # Customer segments
    segmentos = pd.DataFrame({
        'segmento': ['Joven Digital', 'Mamá Emprendedora', 'Mayorista Experimentado'],
        'porcentaje': [35, 40, 25],
        'ticket_promedio': [2500, 4500, 8500],
        'frecuencia_compra': [2.5, 1.8, 1.2]
    })
    
    col1, col2 = st.columns(2)
    
    with col1:
        # Segment distribution
        fig_segments = px.pie(
            segmentos, 
            values='porcentaje', 
            names='segmento',
            title='Distribución de Segmentos de Clientes'
        )
        st.plotly_chart(fig_segments, use_container_width=True)
    
    with col2:
        # Average ticket by segment
        fig_ticket = px.bar(
            segmentos, 
            x='segmento', 
            y='ticket_promedio',
            title='Ticket Promedio por Segmento',
            color='ticket_promedio',
            color_continuous_scale='blues'
        )
        st.plotly_chart(fig_ticket, use_container_width=True)
    
    # Demographic heatmap
    st.subheader("Distribución Demográfica")
    
    # Create a mock heatmap data
    heatmap_data = demograficos.pivot_table(
        values='poblacion_total', 
        index=pd.cut(demograficos['lat'], bins=5), 
        columns=pd.cut(demograficos['lng'], bins=5), 
        aggfunc='sum'
    ).fillna(0)
    
    fig_heatmap = px.imshow(
        heatmap_data.values,
        title='Densidad Poblacional por Zona',
        color_continuous_scale='viridis'
    )
    st.plotly_chart(fig_heatmap, use_container_width=True)
    
    # Segment details
    st.subheader("Detalles de Segmentos")
    st.dataframe(segmentos)

def render_agente_demo():
    """Render the expansion agent demo page"""
    st.header("🤖 Agente de Expansión - Demo")
    st.write("Recomendaciones inteligentes para nuevas ubicaciones")
    
    sucursales, competencia, demograficos = load_demo_data()
    
    # Mock AI recommendations
    recomendaciones = pd.DataFrame({
        'ubicacion': ['Centro Histórico', 'Plaza del Valle', 'Mercado de Abastos', 'Zona Universitaria'],
        'score': [8.5, 7.8, 7.2, 6.9],
        'inversion_estimada': [450000, 380000, 320000, 290000],
        'roi_proyectado': [18.5, 16.2, 14.8, 13.1],
        'riesgo': ['Bajo', 'Medio', 'Medio', 'Alto']
    })
    
    # Top recommendation
    st.subheader("🎯 Recomendación Principal")
    top_rec = recomendaciones.iloc[0]
    
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.metric("Ubicación", top_rec['ubicacion'])
    with col2:
        st.metric("Score", f"{top_rec['score']}/10")
    with col3:
        st.metric("ROI Proyectado", f"{top_rec['roi_proyectado']}%")
    with col4:
        st.metric("Riesgo", top_rec['riesgo'])
    
    # All recommendations
    st.subheader("📋 Todas las Recomendaciones")
    
    # Score visualization
    fig_scores = px.bar(
        recomendaciones, 
        x='ubicacion', 
        y='score',
        title='Puntuación de Ubicaciones Recomendadas',
        color='score',
        color_continuous_scale='greens'
    )
    st.plotly_chart(fig_scores, use_container_width=True)
    
    # Investment vs ROI scatter
    fig_scatter = px.scatter(
        recomendaciones, 
        x='inversion_estimada', 
        y='roi_proyectado',
        size='score',
        color='riesgo',
        hover_name='ubicacion',
        title='Inversión vs ROI Proyectado'
    )
    st.plotly_chart(fig_scatter, use_container_width=True)
    
    # Detailed table
    st.dataframe(recomendaciones)
    
    # Mock analysis text
    st.subheader("💡 Análisis Detallado")
    st.write(f"""
    **Recomendación: {top_rec['ubicacion']}**
    
    Basado en el análisis de datos demográficos, competencia y patrones de consumo, 
    {top_rec['ubicacion']} presenta la mejor oportunidad de expansión con:
    
    - **Alta densidad** de clientes objetivo (segmento joven digital y mamás emprendedoras)
    - **Competencia limitada** en un radio de 500m
    - **Accesibilidad excelente** y alta visibilidad
    - **ROI proyectado** del {top_rec['roi_proyectado']}% en 24 meses
    
    La inversión estimada de ${top_rec['inversion_estimada']:,} incluye:
    - Acondicionamiento del local
    - Inventario inicial
    - Marketing de lanzamiento
    - Capital de trabajo inicial
    """)

def main():
    """Main application function"""
    # Page configuration
    st.set_page_config(
        page_title="Rosa Oliva Geoespacial - Demo",
        page_icon="💎",
        layout="wide",
        initial_sidebar_state="expanded"
    )
    
    # Custom CSS for better styling
    st.markdown("""
    <style>
    .main-header {
        background: linear-gradient(90deg, #FF6B6B, #4ECDC4);
        padding: 1rem;
        border-radius: 10px;
        margin-bottom: 2rem;
    }
    .metric-card {
        background: #f0f2f6;
        padding: 1rem;
        border-radius: 10px;
        border-left: 4px solid #FF6B6B;
    }
    </style>
    """, unsafe_allow_html=True)
    
    # Header
    st.markdown('<div class="main-header">', unsafe_allow_html=True)
    col1, col2 = st.columns([1, 4])
    with col1:
        st.markdown("💎")
    with col2:
        st.title("Rosa Oliva Geoespacial - Demo")
        st.markdown("*Análisis estratégico para expansión de joyería*")
    st.markdown('</div>', unsafe_allow_html=True)
    
    # Demo notice
    st.info("🚀 Esta es una versión demo con datos simulados para fines de demostración.")
    
    # Sidebar navigation
    st.sidebar.title("Navegación")
    st.sidebar.markdown("---")
    
    page = st.sidebar.selectbox(
        "Seleccionar módulo:",
        ["🗺️ Mapa Interactivo", "📊 Análisis Captación", "👥 Socioeconómico", "🤖 Agente Expansión"]
    )
    
    # App info in sidebar
    st.sidebar.markdown("---")
    st.sidebar.markdown("### ℹ️ Información")
    st.sidebar.markdown("""
    **Rosa Oliva Geoespacial** es una herramienta de análisis estratégico 
    para la expansión de joyerías, utilizando:
    
    - 🗺️ Análisis geoespacial
    - 📊 Modelos de captación
    - 👥 Segmentación demográfica  
    - 🤖 IA para recomendaciones
    """)
    
    # Render selected page
    if page == "🗺️ Mapa Interactivo":
        render_mapa_demo()
    elif page == "📊 Análisis Captación":
        render_huff_demo()
    elif page == "👥 Socioeconómico":
        render_socio_demo()
    elif page == "🤖 Agente Expansión":
        render_agente_demo()
    
    # Footer
    st.markdown("---")
    st.markdown(
        f"<div style='text-align: center; color: #666;'>"
        f"Rosa Oliva Geoespacial Demo - {datetime.now().year} | "
        f"Desarrollado con ❤️ usando Streamlit"
        f"</div>", 
        unsafe_allow_html=True
    )

if __name__ == "__main__":
    main()