library(reticulate)

# load R and python functions
for (file in list.files("py")) source_python(file.path("py", file))
for (file in list.files("R")) source(file.path("R", file))

# load data
get_defpea_redif()
parsed_repec <- parse_redif(redif_file = "data-raw/repec/defpea.redif")

# Convert to wide table
df <- purrr::map_df(
  parsed_repec, ~.x |>
    dplyr::filter(!is.na(`key`)) |>
    tidyr::pivot_wider(
      names_from = "key", 
      values_from = "value", 
      values_fn = function(x) paste(x, collapse = ", ")
      )
  )

# output to csv
write.csv(df, "data/defpea_repec.csv", row.names = FALSE)


