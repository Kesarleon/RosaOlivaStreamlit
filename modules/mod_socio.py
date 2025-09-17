"""
Socioeconomic analysis module
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

def render_socio_page():
    st.header("👥 Análisis Socioeconómico")
    
    # Get hexagonal data
    agebs_hex = st.session_state.agebs_hex
    
    if len(agebs_hex) == 0:
        st.error("No hay datos disponibles para el análisis socioeconómico")
        return
    
    # Variable selection
    st.subheader("Selección de Variables")
    
    variable_options = {
        "Joven Digital": "joven_digital",
        "Mamá Emprendedora": "mama_emprendedora",
        "Mayorista Experimentado": "mayorista_experimentado", 
        "Cliente Potencial": "clientes_totales",
        "Población Total": "poblacion_total"
    }
    
    # Multi-select for variables
    selected_vars = st.multiselect(
        "Seleccionar variables para análisis:",
        list(variable_options.keys()),
        default=["Joven Digital", "Mamá Emprendedora", "Cliente Potencial"]
    )
    
    if not selected_vars:
        st.warning("Seleccione al menos una variable para el análisis")
        return
    
    # Create tabs for different analyses
    tab1, tab2, tab3, tab4 = st.tabs(["📊 Histogramas", "📈 Correlaciones", "🗺️ Distribución Espacial", "📋 Estadísticas"])
    
    with tab1:
        render_histograms(agebs_hex, selected_vars, variable_options)
    
    with tab2:
        render_correlations(agebs_hex, selected_vars, variable_options)
    
    with tab3:
        render_spatial_distribution(agebs_hex, selected_vars, variable_options)
    
    with tab4:
        render_statistics(agebs_hex, selected_vars, variable_options)

def render_histograms(agebs_hex, selected_vars, variable_options):
    """Render histogram analysis"""
    st.subheader("Distribución de Variables Socioeconómicas")
    
    # Calculate number of columns for layout
    n_vars = len(selected_vars)
    n_cols = min(2, n_vars)
    n_rows = (n_vars + n_cols - 1) // n_cols
    
    # Create subplots
    fig = make_subplots(
        rows=n_rows,
        cols=n_cols,
        subplot_titles=selected_vars,
        vertical_spacing=0.1
    )
    
    colors = px.colors.qualitative.Set3
    
    for i, var_name in enumerate(selected_vars):
        var_col = variable_options[var_name]
        
        if var_col in agebs_hex.columns:
            data = agebs_hex[var_col].dropna()
            
            if len(data) > 0:
                row = (i // n_cols) + 1
                col = (i % n_cols) + 1
                
                fig.add_trace(
                    go.Histogram(
                        x=data,
                        name=var_name,
                        marker_color=colors[i % len(colors)],
                        opacity=0.7,
                        nbinsx=20
                    ),
                    row=row, col=col
                )
    
    fig.update_layout(
        height=300 * n_rows,
        showlegend=False,
        title_text="Distribuciones de Variables Socioeconómicas"
    )
    
    st.plotly_chart(fig, use_container_width=True)
    
    # Summary statistics
    st.subheader("Estadísticas Descriptivas")
    
    stats_data = []
    for var_name in selected_vars:
        var_col = variable_options[var_name]
        if var_col in agebs_hex.columns:
            data = agebs_hex[var_col].dropna()
            if len(data) > 0:
                stats_data.append({
                    'Variable': var_name,
                    'Media': data.mean(),
                    'Mediana': data.median(),
                    'Desv. Estándar': data.std(),
                    'Mínimo': data.min(),
                    'Máximo': data.max(),
                    'Observaciones': len(data)
                })
    
    if stats_data:
        stats_df = pd.DataFrame(stats_data)
        st.dataframe(stats_df, use_container_width=True, hide_index=True)

def render_correlations(agebs_hex, selected_vars, variable_options):
    """Render correlation analysis"""
    st.subheader("Análisis de Correlaciones")
    
    # Prepare data for correlation
    corr_data = {}
    for var_name in selected_vars:
        var_col = variable_options[var_name]
        if var_col in agebs_hex.columns:
            corr_data[var_name] = agebs_hex[var_col].fillna(0)
    
    if len(corr_data) < 2:
        st.warning("Se necesitan al menos 2 variables para el análisis de correlación")
        return
    
    corr_df = pd.DataFrame(corr_data)
    correlation_matrix = corr_df.corr()
    
    # Create correlation heatmap
    fig = px.imshow(
        correlation_matrix,
        text_auto=True,
        aspect="auto",
        color_continuous_scale="RdBu_r",
        title="Matriz de Correlación entre Variables"
    )
    
    fig.update_layout(height=500)
    st.plotly_chart(fig, use_container_width=True)
    
    # Scatter plots for high correlations
    st.subheader("Relaciones entre Variables")
    
    # Find pairs with high correlation
    high_corr_pairs = []
    for i in range(len(correlation_matrix.columns)):
        for j in range(i+1, len(correlation_matrix.columns)):
            corr_val = correlation_matrix.iloc[i, j]
            if abs(corr_val) > 0.3:  # Threshold for "high" correlation
                high_corr_pairs.append((
                    correlation_matrix.columns[i],
                    correlation_matrix.columns[j],
                    corr_val
                ))
    
    if high_corr_pairs:
        # Show top 3 correlations
        high_corr_pairs.sort(key=lambda x: abs(x[2]), reverse=True)
        
        for i, (var1, var2, corr_val) in enumerate(high_corr_pairs[:3]):
            col1_data = corr_df[var1]
            col2_data = corr_df[var2]
            
            fig = px.scatter(
                x=col1_data,
                y=col2_data,
                title=f"{var1} vs {var2} (r = {corr_val:.3f})",
                labels={'x': var1, 'y': var2},
                trendline="ols"
            )
            
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No se encontraron correlaciones significativas (|r| > 0.3) entre las variables seleccionadas")

def render_spatial_distribution(agebs_hex, selected_vars, variable_options):
    """Render spatial distribution analysis"""
    st.subheader("Distribución Espacial de Variables")
    
    # Variable selection for mapping
    map_var = st.selectbox(
        "Seleccionar variable para mapear:",
        selected_vars
    )
    
    var_col = variable_options[map_var]
    
    if var_col not in agebs_hex.columns:
        st.error(f"Variable {map_var} no disponible en los datos")
        return
    
    # Create choropleth-style visualization
    st.info("💡 Esta visualización muestra la distribución espacial de la variable seleccionada")
    
    # Summary by municipality/locality if available
    if 'nombre_municipio' in agebs_hex.columns:
        st.subheader(f"Resumen por Municipio - {map_var}")
        
        mun_summary = agebs_hex.groupby('nombre_municipio')[var_col].agg([
            'count', 'mean', 'median', 'std', 'min', 'max'
        ]).round(2)
        
        mun_summary.columns = ['Hexágonos', 'Media', 'Mediana', 'Desv. Est.', 'Mínimo', 'Máximo']
        st.dataframe(mun_summary, use_container_width=True)
        
        # Bar chart by municipality
        mun_means = agebs_hex.groupby('nombre_municipio')[var_col].mean().sort_values(ascending=False)
        
        fig = px.bar(
            x=mun_means.index,
            y=mun_means.values,
            title=f"Promedio de {map_var} por Municipio",
            labels={'x': 'Municipio', 'y': f'Promedio {map_var}'}
        )
        
        fig.update_layout(xaxis_tickangle=-45)
        st.plotly_chart(fig, use_container_width=True)
    
    if 'nombre_localidad' in agebs_hex.columns:
        st.subheader(f"Top 10 Localidades - {map_var}")
        
        loc_summary = agebs_hex.groupby('nombre_localidad')[var_col].agg([
            'count', 'mean'
        ]).round(2)
        
        loc_summary.columns = ['Hexágonos', 'Media']
        loc_summary = loc_summary.sort_values('Media', ascending=False).head(10)
        
        fig = px.bar(
            x=loc_summary.index,
            y=loc_summary['Media'],
            title=f"Top 10 Localidades por {map_var}",
            labels={'x': 'Localidad', 'y': f'Promedio {map_var}'}
        )
        
        fig.update_layout(xaxis_tickangle=-45)
        st.plotly_chart(fig, use_container_width=True)

def render_statistics(agebs_hex, selected_vars, variable_options):
    """Render detailed statistics"""
    st.subheader("Estadísticas Detalladas")
    
    # Overall statistics
    st.write("### Estadísticas Generales")
    
    total_hexagons = len(agebs_hex)
    st.metric("Total de Hexágonos", total_hexagons)
    
    if 'poblacion_total' in agebs_hex.columns:
        total_population = agebs_hex['poblacion_total'].sum()
        avg_population = agebs_hex['poblacion_total'].mean()
        st.metric("Población Total", f"{total_population:,.0f}")
        st.metric("Población Promedio por Hexágono", f"{avg_population:.0f}")
    
    # Percentile analysis
    st.write("### Análisis de Percentiles")
    
    percentiles = [10, 25, 50, 75, 90, 95, 99]
    
    for var_name in selected_vars:
        var_col = variable_options[var_name]
        if var_col in agebs_hex.columns:
            data = agebs_hex[var_col].dropna()
            
            if len(data) > 0:
                st.write(f"**{var_name}**")
                
                perc_values = [np.percentile(data, p) for p in percentiles]
                perc_df = pd.DataFrame({
                    'Percentil': [f"P{p}" for p in percentiles],
                    'Valor': perc_values
                })
                
                col1, col2 = st.columns(2)
                
                with col1:
                    st.dataframe(perc_df, hide_index=True)
                
                with col2:
                    # Box plot
                    fig = go.Figure()
                    fig.add_trace(go.Box(
                        y=data,
                        name=var_name,
                        boxpoints='outliers'
                    ))
                    
                    fig.update_layout(
                        title=f"Distribución de {var_name}",
                        height=300
                    )
                    
                    st.plotly_chart(fig, use_container_width=True)
    
    # Data quality report
    st.write("### Reporte de Calidad de Datos")
    
    quality_data = []
    for var_name in selected_vars:
        var_col = variable_options[var_name]
        if var_col in agebs_hex.columns:
            data = agebs_hex[var_col]
            
            quality_data.append({
                'Variable': var_name,
                'Total Registros': len(data),
                'Valores Válidos': data.notna().sum(),
                'Valores Nulos': data.isna().sum(),
                '% Completitud': (data.notna().sum() / len(data) * 100).round(1),
                'Valores Únicos': data.nunique(),
                'Valores Cero': (data == 0).sum()
            })
    
    if quality_data:
        quality_df = pd.DataFrame(quality_data)
        st.dataframe(quality_df, use_container_width=True, hide_index=True)