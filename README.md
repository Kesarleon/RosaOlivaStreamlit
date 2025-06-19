# Rosa Oliva Geoespacial

App desarrollada en **R Shiny** para apoyar la toma de decisiones estratégicas de expansión de **Rosa Oliva**, una joyería enfocada en mercados de alto valor en México.

## Objetivo

Visualizar y analizar:

- Población objetivo por zonas (AGEBs)
- Competencia cercana mediante datos del INEGI (DENUE)
- Captación estimada con modelo de Huff
- AGEBS similares a las de nuestros clientes usando ML
- Nuevas ubicaciones con estimaciones de impacto

## 🗺️ Módulos principales

| Módulo              | Descripción                                                                 |
|---------------------|-----------------------------------------------------------------------------|
| Mapa principal     | Hexágonos por población objetivo, ubicación del usuario y negocios cercanos |
| Modelo Huff       | Estima captación de cada sucursal vs competencia                           |
| Variables socio   | Histograma de variables socioeconómicas por zona                            |
| Agente inteligente| AGEBS similares y evaluación de ubicaciones nuevas                          |

## Estructura del proyecto

RosaOlivaApp/  
├── app.R  
├── global.R  
├── www/ # Archivos visuales: favicon, CSS, íconos  
├── modules/ # Código modular por hoja  
├── models/ # Modelos Huff y ML (Nota: actualmente no hay una carpeta 'models', modelos están en 'utils' o simulados)
├── utils/ # Funciones auxiliares: inegi_denue, helpers, scripts de preparación de datos
├── data/ # Datos simulados y pre-procesados (o reales si se cargan)
├── README.md  

## Data Preparation

La aplicación utiliza datos pre-procesados que se generan mediante scripts ubicados en el directorio `utils/`. Es crucial ejecutar estos scripts si los datos base cambian o si se necesita regenerar los archivos de datos principales utilizados por la aplicación.

Los scripts principales para la preparación de datos son:

1.  **`utils/perfiles.R`**
    *   **Propósito**: Realiza un Análisis de Componentes Principales (PCA) sobre datos censales para identificar y cuantificar perfiles de clientes. Estima el número de clientes potenciales por AGEB para cada perfil.
    *   **Entrada**: Datos del censo a nivel AGEB. Ejemplo: `../data/CensoOaxaca/conjunto_de_datos/conjunto_de_datos_ageb_urbana_20_cpv2020.csv`. (Asegúrate que la ruta sea correcta y el archivo exista).
    *   **Salida**: Un archivo RDS (`data/perfiles.rds`) que contiene los índices de perfiles de clientes y las estimaciones de clientes potenciales por AGEB.

2.  **`utils/oaxaca_grid.R`**
    *   **Propósito**: Genera la cuadrícula hexagonal principal utilizada en la aplicación. Agrega datos de población y los perfiles de clientes (del archivo `perfiles.rds`) a esta cuadrícula.
    *   **Entradas**:
        *   Shapefiles de AGEBs de Oaxaca (ej. `../data/agebs_oaxaca/conjunto_de_datos/*.shp`).
        *   Datos de perfiles de clientes: `data/perfiles.rds` (generado por `utils/perfiles.R`).
    *   **Salida**: El shapefile de la cuadrícula hexagonal (`data/Oaxaca_grid/oaxaca_ZMO_grid.shp`) que es cargado por la aplicación en `global.R`.

**Importante**: Estos scripts (`perfiles.R` y `oaxaca_grid.R`) deben ejecutarse manualmente en la consola de R antes de iniciar la aplicación Shiny si los datos fuente han cambiado o si los archivos `data/perfiles.rds` o `data/Oaxaca_grid/oaxaca_ZMO_grid.shp` no existen o necesitan ser actualizados.

## Configuración

Para obtener la funcionalidad completa de la aplicación, especialmente aquella que interactúa con servicios externos, es necesario configurar claves API como variables de entorno.

### Google Places API Key

*   **Usada por**: El módulo de análisis de captación (`modules/mod_huff.R`), a través de la función `get_google_place_rating` en `utils/google_places.R`, para obtener calificaciones (ratings) de la competencia, que se utilizan como medida de atractivo en el modelo de Huff.
*   **Variable de Entorno**: `GOOGLE_PLACES_API_KEY`
*   **Instrucción**: Configure la variable de entorno `GOOGLE_PLACES_API_KEY` con su clave de API de Google Places.
    *   Ejemplo en R: `Sys.setenv(GOOGLE_PLACES_API_KEY = "TU_API_KEY_AQUI")` (ejecutar antes de iniciar la app, o mejor aún, definirla en su `.Renviron`).

### INEGI API Key

*   **Usada por**: El módulo de mapa principal (`modules/mod_mapa.R`), a través de la función `inegi_denue` en `utils/inegi_denue.R`, para buscar negocios cercanos (DENUE).
*   **Variable de Entorno**: `INEGI_API_KEY`
*   **Instrucción**: Configure la variable de entorno `INEGI_API_KEY` con su clave de API de INEGI.
    *   Ejemplo en R: `Sys.setenv(INEGI_API_KEY = "TU_API_KEY_AQUI")`

**Nota sobre las Claves API**:
Si estas claves API no están configuradas, los módulos correspondientes intentarán recurrir a datos simulados o tendrán una funcionalidad limitada. La aplicación mostrará notificaciones para indicar cuándo se están utilizando datos simulados debido a la ausencia de claves API.
