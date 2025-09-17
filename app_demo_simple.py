"""
Rosa Oliva Geoespacial - Simple Demo Version for Streamlit Cloud
Ultra-simplified version without pandas/numpy dependencies.
"""

import streamlit as st
import random
from datetime import datetime

# Set random seed for consistent demo data
random.seed(42)

# Demo configuration
DEMO_CONFIG = {
    'default_lat': 17.0594,
    'default_lng': -96.7216,
    'app_title': "Rosa Oliva Geoespacial - Demo",
    'app_subtitle': "Análisis estratégico para expansión de joyería"
}

@st.cache_data
def load_demo_data():
    """Load mock data for demonstration using basic Python"""
    
    # Mock store locations
    sucursales = [
        {'id': 'A', 'nombre': 'Sucursal Violetas', 'lat': 17.078904, 'lng': -96.710641, 'atractivo': 4.0, 'ventas_mensuales': 150000},
        {'id': 'B', 'nombre': 'Sucursal Poniente', 'lat': 17.07, 'lng': -96.73, 'atractivo': 4.0, 'ventas_mensuales': 120000},
        {'id': 'C', 'nombre': 'Sucursal Sur', 'lat': 17.05, 'lng': -96.71, 'atractivo': 4.2, 'ventas_mensuales': 180000}
    ]
    
    # Mock competition data
    competencia = [
        {'id': 'X', 'nombre': 'Joyería Nice', 'lat': 17.078891, 'lng': -96.710177, 'rating': 4.2},
        {'id': 'Y', 'nombre': 'Joyería Sublime', 'lat': 17.078206, 'lng': -96.710654, 'rating': 3.8},
        {'id': 'Z', 'nombre': 'Joyería Ag 925', 'lat': 17.080318, 'lng': -96.713559, 'rating': 4.5},
        {'id': 'W', 'nombre': 'Oro y Plata', 'lat': 17.065, 'lng': -96.720, 'rating': 4.0}
    ]
    
    # Mock demographic data
    demograficos = []
    for i in range(30):
        demograficos.append({
            'area_id': f'area_{i+1}',
            'lat': round(17.04 + random.random() * 0.07, 6),
            'lng': round(-96.75 + random.random() * 0.06, 6),
            'poblacion_total': random.randint(500, 3000),
            'joven_digital': random.randint(50, 800),
            'mama_emprendedora': random.randint(30, 600),
            'mayorista_experimentado': random.randint(20, 400),
            'ingreso_promedio': random.randint(8000, 25000)
        })
    
    return sucursales, competencia, demograficos

def render_mapa_demo():
    """Render the map demo page"""
    st.header("🗺️ Mapa Interactivo - Demo")
    st.write("Visualización de sucursales Rosa Oliva y competencia en Oaxaca")
    
    sucursales, competencia, demograficos = load_demo_data()
    
    # Create a simple map visualization using Streamlit's built-in map
    map_data = []
    
    # Add Rosa Oliva stores
    for store in sucursales:
        map_data.append({
            'lat': store['lat'],
            'lon': store['lng'],
            'size': 100,
            'color': [255, 0, 0, 160]  # Red for Rosa Oliva
        })
    
    # Add competition
    for comp in competencia:
        map_data.append({
            'lat': comp['lat'],
            'lon': comp['lng'],
            'size': 80,
            'color': [0, 0, 255, 160]  # Blue for competition
        })
    
    # Display map
    st.map(map_data, zoom=12)
    
    # Show store information
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Sucursales Rosa Oliva")
        for store in sucursales:
            st.write(f"**{store['nombre']}**")
            st.write(f"- Atractivo: {store['atractivo']}/5")
            st.write(f"- Ventas: ${store['ventas_mensuales']:,}")
            st.write("---")
    
    with col2:
        st.subheader("Competencia")
        for comp in competencia:
            st.write(f"**{comp['nombre']}**")
            st.write(f"- Rating: {comp['rating']}/5")
            st.write("---")

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
    huff_results = [
        {'sucursal': 'Sucursal Violetas', 'captacion_estimada': 0.32, 'clientes_potenciales': 1250},
        {'sucursal': 'Sucursal Poniente', 'captacion_estimada': 0.28, 'clientes_potenciales': 980},
        {'sucursal': 'Sucursal Sur', 'captacion_estimada': 0.35, 'clientes_potenciales': 1450}
    ]
    
    # Adjust results based on parameters (simple simulation)
    for result in huff_results:
        adjustment = (alfa - 1.0) * 0.1 + (beta - 2.0) * 0.05
        result['captacion_estimada'] = max(0.1, min(0.5, result['captacion_estimada'] + adjustment))
        result['clientes_potenciales'] = int(result['clientes_potenciales'] * (1 + adjustment))
    
    # Display results
    st.subheader("Resultados del Análisis")
    
    # Create simple bar chart using Streamlit
    chart_data = {}
    for result in huff_results:
        chart_data[result['sucursal']] = result['captacion_estimada']
    
    st.bar_chart(chart_data)
    
    # Results table
    st.subheader("Detalles por Sucursal")
    for result in huff_results:
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("Sucursal", result['sucursal'])
        with col2:
            st.metric("Captación", f"{result['captacion_estimada']:.1%}")
        with col3:
            st.metric("Clientes Pot.", f"{result['clientes_potenciales']:,}")
        st.write("---")

def render_socio_demo():
    """Render the socioeconomic demo page"""
    st.header("👥 Análisis Socioeconómico - Demo")
    st.write("Perfiles de clientes y análisis demográfico")
    
    sucursales, competencia, demograficos = load_demo_data()
    
    # Customer segments
    segmentos = [
        {'segmento': 'Joven Digital', 'porcentaje': 35, 'ticket_promedio': 2500, 'frecuencia_compra': 2.5},
        {'segmento': 'Mamá Emprendedora', 'porcentaje': 40, 'ticket_promedio': 4500, 'frecuencia_compra': 1.8},
        {'segmento': 'Mayorista Experimentado', 'porcentaje': 25, 'ticket_promedio': 8500, 'frecuencia_compra': 1.2}
    ]
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Distribución de Segmentos")
        # Simple pie chart representation
        for seg in segmentos:
            st.write(f"**{seg['segmento']}**: {seg['porcentaje']}%")
            st.progress(seg['porcentaje'] / 100)
    
    with col2:
        st.subheader("Ticket Promedio por Segmento")
        ticket_data = {}
        for seg in segmentos:
            ticket_data[seg['segmento']] = seg['ticket_promedio']
        st.bar_chart(ticket_data)
    
    # Segment details
    st.subheader("Detalles de Segmentos")
    for seg in segmentos:
        with st.expander(f"📊 {seg['segmento']}"):
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Participación", f"{seg['porcentaje']}%")
            with col2:
                st.metric("Ticket Promedio", f"${seg['ticket_promedio']:,}")
            with col3:
                st.metric("Frecuencia/Mes", f"{seg['frecuencia_compra']}")

def render_agente_demo():
    """Render the expansion agent demo page"""
    st.header("🤖 Agente de Expansión - Demo")
    st.write("Recomendaciones inteligentes para nuevas ubicaciones")
    
    sucursales, competencia, demograficos = load_demo_data()
    
    # Mock AI recommendations
    recomendaciones = [
        {'ubicacion': 'Centro Histórico', 'score': 8.5, 'inversion_estimada': 450000, 'roi_proyectado': 18.5, 'riesgo': 'Bajo'},
        {'ubicacion': 'Plaza del Valle', 'score': 7.8, 'inversion_estimada': 380000, 'roi_proyectado': 16.2, 'riesgo': 'Medio'},
        {'ubicacion': 'Mercado de Abastos', 'score': 7.2, 'inversion_estimada': 320000, 'roi_proyectado': 14.8, 'riesgo': 'Medio'},
        {'ubicacion': 'Zona Universitaria', 'score': 6.9, 'inversion_estimada': 290000, 'roi_proyectado': 13.1, 'riesgo': 'Alto'}
    ]
    
    # Top recommendation
    st.subheader("🎯 Recomendación Principal")
    top_rec = recomendaciones[0]
    
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
    score_data = {}
    for rec in recomendaciones:
        score_data[rec['ubicacion']] = rec['score']
    st.bar_chart(score_data)
    
    # Detailed recommendations
    st.subheader("Análisis Detallado")
    for i, rec in enumerate(recomendaciones):
        with st.expander(f"#{i+1} - {rec['ubicacion']} (Score: {rec['score']}/10)"):
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Inversión Estimada", f"${rec['inversion_estimada']:,}")
            with col2:
                st.metric("ROI Proyectado", f"{rec['roi_proyectado']}%")
            with col3:
                st.metric("Nivel de Riesgo", rec['riesgo'])
            
            # Risk color coding
            risk_color = {"Bajo": "🟢", "Medio": "🟡", "Alto": "🔴"}
            st.write(f"**Evaluación de Riesgo**: {risk_color.get(rec['riesgo'], '⚪')} {rec['riesgo']}")
    
    # Mock analysis text
    st.subheader("💡 Análisis Detallado - Centro Histórico")
    st.write(f"""
    **Recomendación Principal: {top_rec['ubicacion']}**
    
    Basado en el análisis de datos demográficos, competencia y patrones de consumo, 
    {top_rec['ubicacion']} presenta la mejor oportunidad de expansión con:
    
    - **Alta densidad** de clientes objetivo (segmento joven digital y mamás emprendedoras)
    - **Competencia limitada** en un radio de 500m
    - **Accesibilidad excelente** y alta visibilidad
    - **ROI proyectado** del {top_rec['roi_proyectado']}% en 24 meses
    
    La inversión estimada de ${top_rec['inversion_estimada']:,} incluye:
    - Acondicionamiento del local: $180,000
    - Inventario inicial: $150,000
    - Marketing de lanzamiento: $70,000
    - Capital de trabajo inicial: $50,000
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
        color: white;
    }
    .metric-card {
        background: #f0f2f6;
        padding: 1rem;
        border-radius: 10px;
        border-left: 4px solid #FF6B6B;
    }
    .stProgress > div > div > div > div {
        background-color: #FF6B6B;
    }
    </style>
    """, unsafe_allow_html=True)
    
    # Header
    st.markdown('<div class="main-header">', unsafe_allow_html=True)
    col1, col2 = st.columns([1, 4])
    with col1:
        st.markdown("# 💎")
    with col2:
        st.title("Rosa Oliva Geoespacial - Demo")
        st.markdown("*Análisis estratégico para expansión de joyería*")
    st.markdown('</div>', unsafe_allow_html=True)
    
    # Demo notice
    st.info("🚀 Esta es una versión demo simplificada con datos simulados para fines de demostración.")
    
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
    
    **Versión**: Demo Simplificada
    **Datos**: Simulados para demostración
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