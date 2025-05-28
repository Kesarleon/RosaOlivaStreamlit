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
├── models/ # Modelos Huff y ML  
├── utils/ # Funciones auxiliares: inegi_denue, helpers  
├── data/ # Datos simulados (o reales si se cargan)  
├── README.md  

