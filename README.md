# Rosa Oliva Geoespacial - Streamlit Version

App desarrollada en **Python Streamlit** para apoyar la toma de decisiones estratégicas de expansión de **Rosa Oliva**, una joyería enfocada en mercados de alto valor en México.

## Objetivo

Visualizar y analizar:

- Población objetivo por zonas (AGEBs) usando hexágonos
- Competencia cercana mediante datos del INEGI (DENUE)
- Captación estimada con modelo de Huff
- AGEBs similares a las de nuestros clientes usando ML
- Nuevas ubicaciones con estimaciones de impacto

## 🗺️ Módulos principales

| Módulo              | Descripción                                                                 |
|---------------------|-----------------------------------------------------------------------------|
| Mapa principal     | Hexágonos por población objetivo, ubicación del usuario y negocios cercanos. Permite la selección interactiva de nuevas ubicaciones para análisis. |
| Modelo Huff       | Estima captación de cada sucursal vs competencia                           |
| Variables socio   | Análisis completo de variables socioeconómicas por zona                     |
| Agente inteligente| AGEBs similares y evaluación de ubicaciones nuevas usando ML               |

## Estructura del proyecto

```
RosaOlivaStreamlit/
├── app.py                 # Aplicación principal Streamlit
├── config.py              # Configuración global y carga de datos
├── requirements.txt       # Dependencias Python
├── README.md             # Este archivo
├── modules/              # Código modular por página
│   ├── __init__.py
│   ├── mod_mapa.py       # Módulo de mapa interactivo
│   ├── mod_huff.py       # Módulo de análisis Huff
│   ├── mod_socio.py      # Módulo socioeconómico
│   └── mod_agente.py     # Módulo de agente inteligente
├── utils/                # Funciones auxiliares
│   ├── __init__.py
│   ├── huff_model.py     # Implementación del modelo Huff
│   ├── inegi_denue.py    # Interacción con API INEGI
│   ├── google_places.py  # Interacción con Google Places API
│   └── helpers.py        # Funciones de ayuda geográficas
├── www/                  # Archivos estáticos
│   ├── modern_theme.css  # Estilos CSS personalizados
│   └── logo_ro.png       # Logo (si está disponible)
└── data/                 # Datos (opcional)
    └── Oaxaca_grid/      # Datos de cuadrícula hexagonal
```

## Instalación y Configuración

### 1. Clonar el repositorio
```bash
git clone <repository-url>
cd RosaOlivaStreamlit
```

### 2. Crear entorno virtual
```bash
python -m venv venv
source venv/bin/activate  # En Windows: venv\Scripts\activate
```

### 3. Instalar dependencias
```bash
pip install -r requirements.txt
```

### 4. Configurar variables de entorno
Crear un archivo `.env` en la raíz del proyecto:

```env
GOOGLE_PLACES_API_KEY=tu_clave_google_places_aqui
INEGI_API_KEY=tu_clave_inegi_aqui
```

### 5. Ejecutar la aplicación
```bash
streamlit run app.py
```

## Uso Interactivo

### Características principales:

1. **Selección de Nueva Ubicación**: Haz clic en cualquier punto del mapa en el **Módulo Mapa Principal**.
2. **Actualización Automática**:
   - El punto seleccionado se convierte en la nueva **sucursal** para el análisis del **Modelo Huff**.
   - El sistema buscará automáticamente los **5 negocios competidores más cercanos** a esa nueva ubicación.
   - Los análisis se actualizarán para reflejar esta nueva selección.

### Navegación:
- Usa la barra lateral para navegar entre módulos
- Cada módulo tiene controles específicos y visualizaciones interactivas
- Los resultados se mantienen en la sesión para análisis cruzado

## Configuración de APIs

### Google Places API Key

- **Usada por**: Módulo de análisis de captación para obtener calificaciones de la competencia
- **Variable de Entorno**: `GOOGLE_PLACES_API_KEY`
- **Configuración**: 
  ```bash
  export GOOGLE_PLACES_API_KEY="TU_API_KEY_AQUI"
  ```

### INEGI API Key

- **Usada por**: Módulo de mapa principal para buscar negocios cercanos (DENUE)
- **Variable de Entorno**: `INEGI_API_KEY`
- **Configuración**:
  ```bash
  export INEGI_API_KEY="TU_API_KEY_AQUI"
  ```

**Nota**: Si estas claves no están configuradas, la aplicación usará datos simulados con funcionalidad limitada.

## Preparación de Datos

La aplicación puede funcionar con:

1. **Datos reales**: Shapefile de cuadrícula hexagonal en `data/Oaxaca_grid/oaxaca_ZMO_grid.shp`
2. **Datos simulados**: Generados automáticamente si no se encuentran datos reales

### Para usar datos reales:
1. Coloca el shapefile de la cuadrícula hexagonal en `data/Oaxaca_grid/`
2. Asegúrate de que contenga las columnas necesarias (ver `config.py`)

## Tecnologías Utilizadas

- **Streamlit**: Framework de aplicación web
- **Folium**: Mapas interactivos
- **Pandas/GeoPandas**: Manipulación de datos geoespaciales
- **Scikit-learn**: Algoritmos de machine learning
- **Plotly**: Visualizaciones interactivas
- **Requests**: Llamadas a APIs externas

## Diferencias con la versión R Shiny

### Ventajas de la versión Streamlit:
- **Más fácil de desplegar**: Streamlit Cloud, Heroku, etc.
- **Mejor integración con ML**: Scikit-learn nativo
- **Visualizaciones modernas**: Plotly integrado
- **Desarrollo más rápido**: Menos código boilerplate
- **Mejor manejo de sesiones**: Estado automático

### Funcionalidades mejoradas:
- **Análisis socioeconómico expandido**: Correlaciones, percentiles, calidad de datos
- **Agente inteligente más avanzado**: Clustering, PCA, análisis predictivo
- **Interfaz más moderna**: CSS personalizado, mejor UX
- **Mejor manejo de errores**: Validaciones y fallbacks

## Despliegue

### Streamlit Cloud (Recomendado)
1. Sube el código a GitHub
2. Conecta con Streamlit Cloud
3. Configura las variables de entorno en la interfaz web
4. Despliega automáticamente

### Docker
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8501

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

### Heroku
1. Crear `Procfile`:
   ```
   web: streamlit run app.py --server.port=$PORT --server.address=0.0.0.0
   ```
2. Configurar variables de entorno en Heroku
3. Desplegar con Git

## Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## Contacto

Rosa Oliva Geoespacial - [contacto@rosaolivageoespacial.com](mailto:contacto@rosaolivageoespacial.com)

Enlace del Proyecto: [https://github.com/tu-usuario/rosa-oliva-streamlit](https://github.com/tu-usuario/rosa-oliva-streamlit)