dpe_themes <- jsonlite::read_json("data-raw/dpe_themes.json") |>
  purrr::flatten() |>
  purrr::map_df(~.x)

usethis::use_data(dpe_themes, overwrite = TRUE)
