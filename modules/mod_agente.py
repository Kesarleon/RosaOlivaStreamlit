"""
AI Agent module for expansion recommendations
"""

import streamlit as st
import pandas as pd
import numpy as np
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.metrics.pairwise import cosine_similarity
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

def render_agente_page():
    st.header("🤖 Agente Inteligente de Expansión")
    
    # Get hexagonal data
    agebs_hex = st.session_state.agebs_hex
    
    if len(agebs_hex) == 0:
        st.error("No hay datos disponibles para el análisis del agente")
        return
    
    # Create tabs for different AI analyses
    tab1, tab2, tab3, tab4 = st.tabs([
        "🎯 Perfiles de Cliente", 
        "📍 Ubicaciones Similares", 
        "🔍 Recomendaciones", 
        "📊 Análisis Predictivo"
    ])
    
    with tab1:
        render_customer_profiles(agebs_hex)
    
    with tab2:
        render_similar_locations(agebs_hex)
    
    with tab3:
        render_recommendations(agebs_hex)
    
    with tab4:
        render_predictive_analysis(agebs_hex)

def render_customer_profiles(agebs_hex):
    """Render customer profile analysis using clustering"""
    st.subheader("Análisis de Perfiles de Cliente")
    
    # Prepare data for clustering
    feature_cols = ['joven_digital', 'mama_emprendedora', 'mayorista_experimentado', 'clientes_totales']
    available_cols = [col for col in feature_cols if col in agebs_hex.columns]
    
    if len(available_cols) < 2:
        st.error("Se necesitan al menos 2 variables para el análisis de perfiles")
        return
    
    # Data preparation
    data_for_clustering = agebs_hex[available_cols].fillna(0)
    
    # Clustering parameters
    col1, col2 = st.columns(2)
    
    with col1:
        n_clusters = st.slider("Número de clusters:", min_value=2, max_value=8, value=4)
        
    with col2:
        use_pca = st.checkbox("Usar PCA para reducción dimensional", value=True)
    
    if st.button("🔄 Ejecutar Análisis de Perfiles"):
        with st.spinner("Analizando perfiles de cliente..."):
            # Standardize data
            scaler = StandardScaler()
            data_scaled = scaler.fit_transform(data_for_clustering)
            
            # Apply PCA if selected
            if use_pca and len(available_cols) > 2:
                pca = PCA(n_components=min(3, len(available_cols)))
                data_for_model = pca.fit_transform(data_scaled)
                
                # Show PCA explained variance
                st.write("### Varianza Explicada por PCA")
                variance_df = pd.DataFrame({
                    'Componente': [f'PC{i+1}' for i in range(len(pca.explained_variance_ratio_))],
                    'Varianza Explicada (%)': pca.explained_variance_ratio_ * 100
                })
                
                fig = px.bar(
                    variance_df, 
                    x='Componente', 
                    y='Varianza Explicada (%)',
                    title="Varianza Explicada por Componente Principal"
                )
                st.plotly_chart(fig, use_container_width=True)
                
            else:
                data_for_model = data_scaled
                pca = None
            
            # Perform clustering
            kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
            clusters = kmeans.fit_predict(data_for_model)
            
            # Add clusters to dataframe
            agebs_with_clusters = agebs_hex.copy()
            agebs_with_clusters['cluster'] = clusters
            
            # Store results in session state
            st.session_state.customer_profiles = {
                'data': agebs_with_clusters,
                'scaler': scaler,
                'pca': pca,
                'kmeans': kmeans,
                'feature_cols': available_cols
            }
            
            # Visualize clusters
            st.write("### Visualización de Clusters")
            
            if data_for_model.shape[1] >= 2:
                fig = px.scatter(
                    x=data_for_model[:, 0],
                    y=data_for_model[:, 1],
                    color=clusters,
                    title="Clusters de Perfiles de Cliente",
                    labels={'x': 'Dimensión 1', 'y': 'Dimensión 2'},
                    color_continuous_scale='viridis'
                )
                st.plotly_chart(fig, use_container_width=True)
            
            # Cluster characteristics
            st.write("### Características de los Clusters")
            
            cluster_summary = agebs_with_clusters.groupby('cluster')[available_cols].mean().round(2)
            cluster_counts = agebs_with_clusters['cluster'].value_counts().sort_index()
            
            cluster_summary['Hexágonos'] = cluster_counts.values
            cluster_summary['% del Total'] = (cluster_counts.values / len(agebs_with_clusters) * 100).round(1)
            
            st.dataframe(cluster_summary, use_container_width=True)
            
            # Radar chart for cluster profiles
            st.write("### Perfiles de Cluster (Radar Chart)")
            
            fig = go.Figure()
            
            for cluster_id in range(n_clusters):
                cluster_data = cluster_summary.loc[cluster_id, available_cols]
                
                fig.add_trace(go.Scatterpolar(
                    r=cluster_data.values,
                    theta=cluster_data.index,
                    fill='toself',
                    name=f'Cluster {cluster_id}',
                    opacity=0.6
                ))
            
            fig.update_layout(
                polar=dict(
                    radialaxis=dict(visible=True, range=[0, cluster_summary[available_cols].max().max()])
                ),
                showlegend=True,
                title="Perfiles de Clusters por Variables"
            )
            
            st.plotly_chart(fig, use_container_width=True)

def render_similar_locations(agebs_hex):
    """Find locations similar to existing successful stores"""
    st.subheader("Búsqueda de Ubicaciones Similares")
    
    # Check if we have customer profiles
    if 'customer_profiles' not in st.session_state:
        st.warning("⚠️ Primero ejecute el análisis de perfiles de cliente en la pestaña anterior")
        return
    
    profiles_data = st.session_state.customer_profiles
    agebs_with_clusters = profiles_data['data']
    
    # Select reference location
    st.write("### Selección de Ubicación de Referencia")
    
    # Option 1: Use existing store locations
    reference_option = st.radio(
        "Seleccionar tipo de referencia:",
        ["Sucursal existente", "Ubicación seleccionada en mapa", "Coordenadas manuales"]
    )
    
    reference_location = None
    
    if reference_option == "Sucursal existente":
        from config import APP_CONFIG
        sucursales = APP_CONFIG['sucursales_rosa_data']
        
        selected_store = st.selectbox(
            "Seleccionar sucursal:",
            sucursales['nombre'].tolist()
        )
        
        store_data = sucursales[sucursales['nombre'] == selected_store].iloc[0]
        reference_location = {'lat': store_data['lat'], 'lng': store_data['lng']}
        
    elif reference_option == "Ubicación seleccionada en mapa":
        map_data = st.session_state.get('map_data', {})
        if map_data.get('clicked_sucursal'):
            reference_location = map_data['clicked_sucursal']
            st.success("✅ Usando ubicación seleccionada en el mapa")
        else:
            st.warning("⚠️ No hay ubicación seleccionada en el mapa")
            
    else:  # Manual coordinates
        col1, col2 = st.columns(2)
        with col1:
            ref_lat = st.number_input("Latitud:", value=17.0594, format="%.6f")
        with col2:
            ref_lng = st.number_input("Longitud:", value=-96.7216, format="%.6f")
        
        reference_location = {'lat': ref_lat, 'lng': ref_lng}
    
    if reference_location and st.button("🔍 Buscar Ubicaciones Similares"):
        with st.spinner("Buscando ubicaciones similares..."):
            similar_locations = find_similar_locations(
                agebs_with_clusters, 
                reference_location,
                profiles_data
            )
            
            if len(similar_locations) > 0:
                st.success(f"✅ Se encontraron {len(similar_locations)} ubicaciones similares")
                
                # Display results
                st.write("### Ubicaciones Similares Encontradas")
                
                display_cols = ['id_hex', 'similarity_score', 'cluster', 'distance_km']
                if 'nombre_municipio' in similar_locations.columns:
                    display_cols.extend(['nombre_municipio', 'nombre_localidad'])
                
                display_cols.extend(['joven_digital', 'mama_emprendedora', 'mayorista_experimentado', 'clientes_totales'])
                
                available_display_cols = [col for col in display_cols if col in similar_locations.columns]
                
                st.dataframe(
                    similar_locations[available_display_cols].head(10),
                    use_container_width=True,
                    hide_index=True
                )
                
                # Visualization
                st.write("### Distribución de Similitud")
                
                fig = px.histogram(
                    similar_locations,
                    x='similarity_score',
                    nbins=20,
                    title="Distribución de Puntuaciones de Similitud"
                )
                st.plotly_chart(fig, use_container_width=True)
                
                # Store results
                st.session_state.similar_locations = similar_locations
                
            else:
                st.warning("⚠️ No se encontraron ubicaciones similares")

def render_recommendations(agebs_hex):
    """Generate expansion recommendations"""
    st.subheader("Recomendaciones de Expansión")
    
    # Check prerequisites
    if 'customer_profiles' not in st.session_state:
        st.warning("⚠️ Primero ejecute el análisis de perfiles de cliente")
        return
    
    profiles_data = st.session_state.customer_profiles
    agebs_with_clusters = profiles_data['data']
    
    # Recommendation parameters
    st.write("### Parámetros de Recomendación")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        min_population = st.number_input(
            "Población mínima:", 
            value=500, 
            min_value=0, 
            step=100
        )
    
    with col2:
        min_clients = st.number_input(
            "Clientes potenciales mínimos:", 
            value=3.0, 
            min_value=0.0, 
            step=0.5
        )
    
    with col3:
        top_n = st.number_input(
            "Top N recomendaciones:", 
            value=10, 
            min_value=5, 
            max_value=50
        )
    
    if st.button("🎯 Generar Recomendaciones"):
        with st.spinner("Generando recomendaciones..."):
            recommendations = generate_recommendations(
                agebs_with_clusters,
                min_population,
                min_clients,
                top_n
            )
            
            if len(recommendations) > 0:
                st.success(f"✅ Se generaron {len(recommendations)} recomendaciones")
                
                # Display recommendations
                st.write("### Top Recomendaciones de Expansión")
                
                display_cols = ['id_hex', 'expansion_score', 'cluster']
                if 'nombre_municipio' in recommendations.columns:
                    display_cols.extend(['nombre_municipio', 'nombre_localidad'])
                
                display_cols.extend([
                    'poblacion_total', 'clientes_totales', 
                    'joven_digital', 'mama_emprendedora', 'mayorista_experimentado'
                ])
                
                available_display_cols = [col for col in display_cols if col in recommendations.columns]
                
                st.dataframe(
                    recommendations[available_display_cols],
                    use_container_width=True,
                    hide_index=True
                )
                
                # Visualization
                col1, col2 = st.columns(2)
                
                with col1:
                    fig = px.bar(
                        recommendations.head(10),
                        x='expansion_score',
                        y='id_hex',
                        orientation='h',
                        title="Top 10 Puntuaciones de Expansión"
                    )
                    fig.update_layout(yaxis={'categoryorder': 'total ascending'})
                    st.plotly_chart(fig, use_container_width=True)
                
                with col2:
                    if 'cluster' in recommendations.columns:
                        cluster_counts = recommendations['cluster'].value_counts()
                        
                        fig = px.pie(
                            values=cluster_counts.values,
                            names=cluster_counts.index,
                            title="Distribución por Cluster"
                        )
                        st.plotly_chart(fig, use_container_width=True)
                
                # Store recommendations
                st.session_state.expansion_recommendations = recommendations
                
            else:
                st.warning("⚠️ No se generaron recomendaciones con los parámetros especificados")

def render_predictive_analysis(agebs_hex):
    """Render predictive analysis and impact estimation"""
    st.subheader("Análisis Predictivo de Impacto")
    
    # Check if we have recommendations
    if 'expansion_recommendations' not in st.session_state:
        st.warning("⚠️ Primero genere recomendaciones en la pestaña anterior")
        return
    
    recommendations = st.session_state.expansion_recommendations
    
    # Impact estimation parameters
    st.write("### Parámetros de Estimación de Impacto")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        capture_rate = st.slider(
            "Tasa de captación estimada (%):", 
            min_value=1, 
            max_value=50, 
            value=15
        ) / 100
    
    with col2:
        avg_ticket = st.number_input(
            "Ticket promedio ($):", 
            value=1500, 
            min_value=100, 
            step=100
        )
    
    with col3:
        visits_per_year = st.number_input(
            "Visitas por cliente/año:", 
            value=2.5, 
            min_value=0.5, 
            step=0.5
        )
    
    # Calculate impact
    if st.button("📊 Calcular Impacto Estimado"):
        with st.spinner("Calculando impacto..."):
            impact_analysis = calculate_impact_estimation(
                recommendations,
                capture_rate,
                avg_ticket,
                visits_per_year
            )
            
            # Display impact results
            st.write("### Estimación de Impacto por Ubicación")
            
            impact_cols = [
                'id_hex', 'expansion_score', 'clientes_potenciales',
                'clientes_captados', 'ingresos_anuales_estimados', 'roi_estimado'
            ]
            
            if 'nombre_municipio' in impact_analysis.columns:
                impact_cols.insert(1, 'nombre_municipio')
                impact_cols.insert(2, 'nombre_localidad')
            
            available_impact_cols = [col for col in impact_cols if col in impact_analysis.columns]
            
            st.dataframe(
                impact_analysis[available_impact_cols].head(10),
                use_container_width=True,
                hide_index=True
            )
            
            # Summary metrics
            st.write("### Resumen de Impacto")
            
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                total_clients = impact_analysis['clientes_captados'].sum()
                st.metric("Clientes Captados Total", f"{total_clients:,.0f}")
            
            with col2:
                total_revenue = impact_analysis['ingresos_anuales_estimados'].sum()
                st.metric("Ingresos Anuales Estimados", f"${total_revenue:,.0f}")
            
            with col3:
                avg_roi = impact_analysis['roi_estimado'].mean()
                st.metric("ROI Promedio", f"{avg_roi:.1f}%")
            
            with col4:
                best_location = impact_analysis.loc[0, 'id_hex']
                st.metric("Mejor Ubicación", best_location)
            
            # Visualizations
            col1, col2 = st.columns(2)
            
            with col1:
                fig = px.scatter(
                    impact_analysis.head(20),
                    x='expansion_score',
                    y='ingresos_anuales_estimados',
                    size='clientes_captados',
                    title="Puntuación vs Ingresos Estimados",
                    labels={
                        'expansion_score': 'Puntuación de Expansión',
                        'ingresos_anuales_estimados': 'Ingresos Anuales Estimados'
                    }
                )
                st.plotly_chart(fig, use_container_width=True)
            
            with col2:
                fig = px.bar(
                    impact_analysis.head(10),
                    x='roi_estimado',
                    y='id_hex',
                    orientation='h',
                    title="ROI Estimado por Ubicación"
                )
                fig.update_layout(yaxis={'categoryorder': 'total ascending'})
                st.plotly_chart(fig, use_container_width=True)

# Helper functions

def find_similar_locations(agebs_with_clusters, reference_location, profiles_data):
    """Find locations similar to reference using cosine similarity"""
    
    # Find nearest hexagon to reference location
    agebs_with_clusters['distance_to_ref'] = np.sqrt(
        (agebs_with_clusters.geometry.centroid.y - reference_location['lat'])**2 +
        (agebs_with_clusters.geometry.centroid.x - reference_location['lng'])**2
    )
    
    nearest_hex = agebs_with_clusters.loc[agebs_with_clusters['distance_to_ref'].idxmin()]
    
    # Prepare feature data
    feature_cols = profiles_data['feature_cols']
    scaler = profiles_data['scaler']
    
    # Get reference features
    ref_features = nearest_hex[feature_cols].values.reshape(1, -1)
    ref_features_scaled = scaler.transform(ref_features)
    
    # Get all features
    all_features = agebs_with_clusters[feature_cols].fillna(0)
    all_features_scaled = scaler.transform(all_features)
    
    # Calculate similarity
    similarities = cosine_similarity(ref_features_scaled, all_features_scaled)[0]
    
    # Add similarity scores
    agebs_with_clusters = agebs_with_clusters.copy()
    agebs_with_clusters['similarity_score'] = similarities
    
    # Calculate distances in km (approximate)
    agebs_with_clusters['distance_km'] = agebs_with_clusters['distance_to_ref'] * 111  # Rough conversion to km
    
    # Filter and sort
    similar_locations = agebs_with_clusters[
        (agebs_with_clusters['similarity_score'] > 0.7) &  # High similarity threshold
        (agebs_with_clusters['distance_km'] > 1)  # Exclude very close locations
    ].sort_values('similarity_score', ascending=False)
    
    return similar_locations

def generate_recommendations(agebs_with_clusters, min_population, min_clients, top_n):
    """Generate expansion recommendations based on multiple criteria"""
    
    # Filter by minimum criteria
    filtered_data = agebs_with_clusters[
        (agebs_with_clusters['poblacion_total'] >= min_population) &
        (agebs_with_clusters['clientes_totales'] >= min_clients)
    ].copy()
    
    if len(filtered_data) == 0:
        return pd.DataFrame()
    
    # Calculate expansion score
    # Normalize features
    features_for_score = ['poblacion_total', 'clientes_totales', 'joven_digital', 
                         'mama_emprendedora', 'mayorista_experimentado']
    
    available_features = [col for col in features_for_score if col in filtered_data.columns]
    
    # Simple scoring: weighted sum of normalized features
    weights = {
        'poblacion_total': 0.2,
        'clientes_totales': 0.4,
        'joven_digital': 0.15,
        'mama_emprendedora': 0.15,
        'mayorista_experimentado': 0.1
    }
    
    filtered_data['expansion_score'] = 0
    
    for feature in available_features:
        if feature in weights:
            # Normalize to 0-1 scale
            normalized = (filtered_data[feature] - filtered_data[feature].min()) / \
                        (filtered_data[feature].max() - filtered_data[feature].min())
            
            filtered_data['expansion_score'] += normalized * weights[feature]
    
    # Sort by score and return top N
    recommendations = filtered_data.sort_values('expansion_score', ascending=False).head(top_n)
    
    return recommendations

def calculate_impact_estimation(recommendations, capture_rate, avg_ticket, visits_per_year):
    """Calculate estimated business impact for recommended locations"""
    
    impact_data = recommendations.copy()
    
    # Calculate potential clients (using clientes_totales as base)
    impact_data['clientes_potenciales'] = impact_data['clientes_totales'] * 100  # Scale up from log values
    
    # Calculate captured clients
    impact_data['clientes_captados'] = impact_data['clientes_potenciales'] * capture_rate
    
    # Calculate annual revenue
    impact_data['ingresos_anuales_estimados'] = (
        impact_data['clientes_captados'] * avg_ticket * visits_per_year
    )
    
    # Estimate ROI (simplified - assumes fixed costs)
    fixed_cost_estimate = 500000  # Estimated setup cost
    impact_data['roi_estimado'] = (
        (impact_data['ingresos_anuales_estimados'] - fixed_cost_estimate * 0.3) / 
        fixed_cost_estimate * 100
    )
    
    return impact_data.sort_values('ingresos_anuales_estimados', ascending=False)