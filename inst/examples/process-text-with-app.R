library(dpe)
library(rcrossref)

setup_python_env()

pdf_data <- extract_from_pdf()
pdf_data

dois <- pdf_data |>
  dplyr::pull(doi)

crossref <- cr_works(dois = dois)

crossref_pdf  <- crossref$data |>
  dplyr::select(doi, volume, issue, page, title, author, url, published.print, published.online) |>
  dplyr::mutate(published.date = ifelse(is.na(published.print), published.online, published.print)) |>
  dplyr::select(-published.online, -published.date) |>
  tidyr::separate(page, c("page_start", "page_end"), sep = "-") |>
  dplyr::mutate(page_start = as.numeric(page_start), 
                page_end = as.numeric(page_end)) |>
  dplyr::arrange(volume, issue, page_start) |>
  dplyr::left_join(pdf_data, by = "doi") 

saveRDS(crossref_pdf, "inst/examples/process-text-with-app.RDS")
