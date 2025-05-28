# Cargar shapefile
shp_path <- list.files("data/agebs_oaxaca/conjunto_de_datos", pattern = "\\.shp$", full.names = TRUE)
agebs_oax <- st_read(shp_path[1], quiet = TRUE)

# ZMO ####

mun_zmo <- c(
  '045',
  '063',
  '067',
  '083',
  '087',
  '091',
  '107',
  '115',
  '157',
  '174',
  '227',
  '293',
  '338',
  '350',
  '375',
  '385',
  '390',
  '399',
  '403',
  '409',
  '519',
  '539',
  '553',
  '565'
)

agebs_oax <- agebs_oax %>% 
  filter(CVE_MUN %in% mun_zmo) 


# Cargar datos de población (asume que viene en el DBF o archivo separado)
# Puedes adaptar esta parte si ya tienes población en otro archivo
# Por ejemplo:
pob_data <- read_csv("data/Pruebas/poboax.csv")
agebs_oax <- left_join(agebs_oax, pob_data, by = "CVEGEO")

agebs_oax <- agebs_oax %>%
  mutate(
    mercado_potencial = (
      #      0.4 * POBTOT +
      #        0.6 * P_15A49_F
      POBTOT
    )
  )

# Transformar a proyección métrica para trabajar en metros
#agebs_oax_proj <- st_transform(agebs_oax, crs = 6372) # UTM zona 14N (aprox para Oaxaca)

# Crear un grid hexagonal sobre todo el estado
hex_size <- 500  # Tamaño de cada hexágono en metros
hex_grid <- st_make_grid(st_transform(agebs_oax, crs = 6372),
                         cellsize = hex_size,
                         square = FALSE,
                         what = "polygons") |> 
  st_sf() |> 
  st_transform(crs = st_crs(agebs_oax)) # Regresamos a WGS84


# Intersecar AGEBs con el grid
hex_grid$id_hex <- 1:nrow(hex_grid)



# Intersección espacial y suma ponderada de población por hexágono
interseccion <- st_intersection(st_make_valid(hex_grid), st_make_valid(agebs_oax))

# Calcular proporción de intersección de cada AGEB dentro de cada hexágono
interseccion <- interseccion %>%
  mutate(area_inter = st_area(.)) %>%
  group_by(id_hex) %>%
  summarise(poblacion = sum(as.numeric(mercado_potencial), na.rm = TRUE),
            ingreso = sum(as.numeric(POBFEM), na.rm = TRUE),
            escolaridad = sum(as.numeric(P_15A49_F), na.rm = TRUE))


# Unir población al grid original
hex_grid <- st_join(hex_grid, interseccion, by = "id_hex")
hex_grid <- hex_grid %>% filter(!is.na(id_hex.y))
hex_grid$poblacion[is.na(hex_grid$poblacion)] <- 0
hex_grid$escolaridad[is.na(hex_grid$escolaridad)] <- 0
hex_grid$ingreso[is.na(hex_grid$ingreso)] <- 0

hex_grid <- hex_grid %>% st_transform('+proj=longlat +datum=WGS84')

st_write(hex_grid, "data/Oaxaca_grid/oaxaca_ZMO_grid.shp")
