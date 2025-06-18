# =====================================
# Script: pca_perfiles_clientes.R
# Análisis PCA por perfil con FactoMineR
# =====================================

# 1. Cargar paquetes
library(tidyverse)
library(FactoMineR)
library(factoextra)
library(tibble)
library(scales)

# 2. Cargar variables AGEBS

oaxaca_censo <- read.csv("../data/CensoOaxaca/conjunto_de_datos/conjunto_de_datos_ageb_urbana_20_cpv2020.csv")

oaxaca_censo <- oaxaca_censo %>% 
  filter(grepl('^Total',NOM_LOC)==FALSE) %>% 
  mutate(across(
    .cols = where(is.character),
    .fns = ~ ifelse(. == "*", NA_character_, .)
    )
    )

oaxaca_censo <- oaxaca_censo %>% 
  mutate_at(c(9:ncol(oaxaca_censo)), as.numeric)

oaxaca_censo <- oaxaca_censo %>% 
  mutate(CVEGEO = paste0(sprintf('%02d',ENTIDAD),
                         sprintf('%03d',MUN),
                         sprintf('%04d',LOC),
                         sprintf('%04s',AGEB)
                         )
         )




oaxaca_censo %>% glimpse()
# Emprendedor Joven Digital (18–28 años, acceso digital, educación media)
vars_joven <- c('P_18A24',
                'P18A24A',
                'PEA',
                'GRAPROES',
                'TVIVPARHAB',
                'VPH_PC',
                'VPH_CEL',
                'VPH_INTER',
                'VPH_SINTIC'
)

# Mamá Emprendedora (28–40 años, mujeres jefas, niños, ingreso medio)
vars_mama <- c('P_15A49_F',
               'P_15A17_F',
               'P_18A24_F',
               'PROM_HNV',
               'P18YM_PB_F',
               'GRAPROES_F',
               'POCUPADA_F',
               'TOTHOG',
               'HOGJEF_F',
               'PHOGJEF_F',
               'VPH_CEL',
               'VPH_INTER'
               )

# Mayorista Experimentado (35–50 años, educación alta, viviendas con auto, población urbana consolidada)
vars_mayorista <- c('POBTOT', 
                    'POB0_14', 
                    'P_15A17', 
                    'P_18A24', 
                    'P_60YMAS', 
                    "P18YM_PB", 
                    "VPH_AUTOM")

# 3. Función para hacer PCA por perfil
hacer_pca_perfil <- function(data, variables, nombre_perfil) {
  sub <- data %>% select(all_of(variables))
  
  # Ejecutar PCA
  res.pca <- PCA(sub, scale.unit = TRUE, graph = FALSE)
  
  # Extraer el primer componente como índice
  indice <- res.pca$ind$coord[, 1]
  data[[paste0("indice_", nombre_perfil)]] <- indice
  
  # Análisis visual
  print(paste("Perfil:", nombre_perfil))
  print(res.pca$eig[1:3, ])
  fviz_contrib(res.pca, choice = "var", axes = 1, top = length(variables)) +
    labs(title = paste("Contribución de variables -", nombre_perfil))
  
  return(list(data = data, pca = res.pca))
}

oaxaca_ageb <- oaxaca_censo %>% 
  select(all_of(c('CVEGEO', 'NOM_ENT', 'NOM_MUN', 'NOM_LOC', 'AGEB', vars_joven,vars_mama,vars_mayorista ))) 

oaxaca_ageb <- oaxaca_ageb %>% 
  group_by(across(all_of(c('CVEGEO', 'NOM_ENT', 'NOM_MUN', 'NOM_LOC', 'AGEB')))) %>% 
  summarise(across(all_of(c(vars_joven, vars_mama, vars_mayorista)),
                   ~sum(., na.rm = TRUE)),
            .groups = 'drop')



res_joven <- hacer_pca_perfil(
  oaxaca_ageb %>% 
    mutate(VPH_SINTIC = VPH_SINTIC*(-1)) %>% 
    select(all_of(vars_joven)) 
  ,
  vars_joven,
  "joven_digital"
)


res_mama <- hacer_pca_perfil(
  oaxaca_ageb %>% 
    mutate(POB_MAMA = P_15A49_F-P_15A17_F-P_18A24_F) %>% 
    select(all_of(c('POB_MAMA', vars_mama))) 
  ,
  vars_mama,
  "mama_emprendedora"
)

res_mayorista <- hacer_pca_perfil(
  oaxaca_ageb %>% 
    mutate(POB_MAYOR = POBTOT-POB0_14-P_15A17-P_18A24-P_60YMAS) %>% 
    select(all_of(c('POB_MAYOR', vars_mayorista))) 
  ,
  vars_mayorista,
  "mayorista_experimentado"
)


agebs_perfiles <- cbind(oaxaca_ageb,
                        res_joven$data %>% select(indice_joven_digital),
                        res_mama$data %>% select(indice_mama_emprendedora),
                        res_mayorista$data %>% select(indice_mayorista_experimentado))


agebs_potencial <- agebs_perfiles %>% 
  mutate(afinidad_joven = rescale(indice_joven_digital),
         afinidad_mama = rescale(indice_mama_emprendedora),
         afinidad_mayorista = rescale(indice_mayorista_experimentado),
         
         estimado_ctes_joven = round((P18A24A)*afinidad_joven*0.60),
         estimado_ctes_mama = round((P_15A49_F-P_15A17_F-P_18A24_F)*afinidad_mama*0.30),
         estimado_ctes_mayorista = round((P18YM_PB)*afinidad_mayorista*0.10),
         estimado_ctes_total = round(pmin((estimado_ctes_joven + estimado_ctes_mama + estimado_ctes_mayorista), POBTOT*0.3))
         )


  
agebs_potencial %>% 
  select(POBTOT, starts_with('estimado')) %>% 
  mutate(porc_joven = estimado_ctes_joven/POBTOT,
         porc_mama = estimado_ctes_mama/POBTOT,
         porc_mayorista = estimado_ctes_mayorista/POBTOT
         ) %>% 
  summary()


library(ggplot2)
ggplot(agebs_potencial, aes(x = estimado_ctes_joven)) + geom_histogram()
ggplot(agebs_potencial, aes(x = estimado_ctes_mama)) + geom_histogram()
ggplot(agebs_potencial, aes(x = estimado_ctes_mayorista)) + geom_histogram()
# ggplot(agebs_hex, aes(fill = perfil_mama_emprendedora)) + geom_sf()

agebs_potencial %>% glimpse()

agebs_potencial_f <- agebs_potencial %>% 
  select_if(sapply(.,is.character) | 
              names(.) == 'POBTOT'|
              names(.) == 'estimado_ctes_joven'|
              names(.) == 'estimado_ctes_mama'|
              names(.) == 'estimado_ctes_mayorista'|
              names(.) == 'estimado_ctes_total'
              
            ) %>% 
  mutate(estimado_ctes_joven = estimado_ctes_joven + 5,
         estimado_ctes_mama = estimado_ctes_mama + 5,
         estimado_ctes_mayorista = estimado_ctes_mayorista + 5,
         estimado_ctes_total = estimado_ctes_total + 5
         )



agebs_potencial_f %>% glimpse()

saveRDS(agebs_potencial_f, file = 'data/perfiles.rds')

# Instala el paquete si no lo tienes
install.packages("ggExtra")

# Carga librerías
library(ggplot2)
library(ggExtra)

# Crea scatterplot base con ggplot2
p <- ggplot(agebs_potencial, aes(x = POBTOT, y = estimado_ctes_joven)) +
  geom_point(color = "steelblue", size = 2) +
  theme_minimal()


# Añade histogramas marginales
ggMarginal(p, type = "histogram", fill = "gray", color = "black")


library(devtools)
devtools::install_github("ggobi/ggally")

library(GGally)

ggpairs(mtcars[, 1:4])

agebs_potencial_f %>% 
  select(POBTOT, starts_with('estimado')) %>% 
  ggpairs()

pob_data <- readRDS('data/perfiles.rds')

library(ggplot2)
ggplot(pob_data, aes(x = 1+log(1+log(estimado_ctes_joven)))) + geom_histogram()
ggplot(pob_data, aes(x = 1+log(estimado_ctes_joven))) + geom_histogram()
ggplot(pob_data, aes(x = estimado_ctes_total)) + geom_histogram()

pob_data %>% summary()
