
library(rcrossref)

d <- "data-raw/vol-35-extract"
files <- file.path(d, list.files(d))

df <- purrr::map_df(files, ~readr::read_csv(.x))

dois <- df |>
  dplyr::pull(doi)

crossref <- cr_works(dois = dois)
names(crossref$data)

dpe_vol_35 <- crossref$data |>
  dplyr::select(doi, volume, issue, page, title, author, url, published.print, published.online) |>
  dplyr::mutate(published.date = ifelse(is.na(published.print), published.online, published.print)) |>
  dplyr::select(-published.online, -published.date) |>
  tidyr::separate(page, c("page_start", "page_end"), sep = "-") |>
  dplyr::mutate(page_start = as.numeric(page_start), 
                page_end = as.numeric(page_end)) |>
  dplyr::arrange(volume, issue, page_start) |>
  dplyr::left_join(df, by = "doi") 

usethis::use_data(dpe_vol_35, overwrite = TRUE)
