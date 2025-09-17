"""
Rosa Oliva Geoespacial - Streamlit App
Main application file for the Streamlit dashboard.
"""

import streamlit as st
import pandas as pd
import numpy as np
from pathlib import Path
import sys

# Add utils to path
sys.path.append(str(Path(__file__).parent / "utils"))

# Import configuration and modules
from config import APP_CONFIG, load_global_data
from modules.mod_mapa import render_mapa_page
from modules.mod_huff import render_huff_page  
from modules.mod_socio import render_socio_page
from modules.mod_agente import render_agente_page

def main():
    # Page configuration
    st.set_page_config(
        page_title="Rosa Oliva Geoespacial",
        page_icon="💎",
        layout="wide",
        initial_sidebar_state="expanded"
    )
    
    # Load custom CSS
    css_file = Path("www/modern_theme.css")
    if css_file.exists():
        with open(css_file) as f:
            st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)
    
    # Header with logo
    col1, col2 = st.columns([1, 4])
    with col1:
        logo_path = Path("www/logo_ro.png")
        if logo_path.exists():
            st.image(str(logo_path), width=120)
    with col2:
        st.title("Rosa Oliva Geoespacial")
        st.markdown("*Análisis estratégico para expansión de joyería*")
    
    # Initialize session state
    if 'agebs_hex' not in st.session_state:
        st.session_state.agebs_hex = load_global_data()
    
    if 'map_data' not in st.session_state:
        st.session_state.map_data = {
            'clicked_sucursal': None,
            'competencia': None
        }
    
    # Sidebar navigation
    st.sidebar.title("Navegación")
    page = st.sidebar.selectbox(
        "Seleccionar módulo:",
        ["🗺️ Mapa", "📊 Análisis Captación", "👥 Socioeconómico", "🤖 Agente Expansión"]
    )
    
    # Render selected page
    if page == "🗺️ Mapa":
        render_mapa_page()
    elif page == "📊 Análisis Captación":
        render_huff_page()
    elif page == "👥 Socioeconómico":
        render_socio_page()
    elif page == "🤖 Agente Expansión":
        render_agente_page()

if __name__ == "__main__":
    main()