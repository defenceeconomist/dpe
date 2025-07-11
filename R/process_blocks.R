#' Extract pdf blocks 
#' 
#' Use pymupdf to extract text blocks from pdf document
#' 
#'@examples py_pdf_blocks("data-raw/onedrive/2024 35 2/00-Prospects of Deterrence_ Deterrence Theory_ Representation and Evidence.pdf")
#'@export
py_pdf_blocks <- function(filepath){
  reticulate::source_python(system.file("python/process_article.py", package = "dpe"))
  extract_blocks(filepath)
}


#' Count Tokens
#' 
#' Use python tiktoken package to count the tokens in full text for a given model
#' 
#'@examples
#' py_pdf_blocks("data-raw/onedrive/2024 35 2/00-Prospects of Deterrence_ Deterrence Theory_ Representation and Evidence.pdf") |>
#'   process_blocks() |>
#'   purrr::pluck("full_text") |>
#'   py_count_tokens()
#'@export
py_count_tokens <- function(x){
  reticulate::source_python(system.file("python/count_tokens.py", package = "dpe"))
  count_tokens(x) 
}

#' Process PDF data
#' 
#' Extract data from pdf.
#' @export
process_blocks <- function(pdf_blocks){
  blocks_tbl <- pdf_blocks |>
    purrr::map_df(~.x) 
  
  # regular expression to extract the text after doi.org/
  # - ([0-9]{2}): matches two digits
  # - \\. : matches a literal dot
  # - [0-9a-zA-Z.-]+: matches one or more alphanumeric characters, dots, or hyphens (the rest of the DOI)
  
  doi_regex <- "([0-9]{2}\\.[0-9]+/[0-9a-zA-Z.-]+)" 
  doi <- blocks_tbl |>
    dplyr::filter(`page` == 0) |>
    dplyr::filter(stringr::str_detect(content, "^To link to this")) |>
    dplyr::pull(`content`) |>
    stringr::str_extract(doi_regex)
  
  jel <- blocks_tbl |>
    dplyr::filter(`page` == 1) |>
    dplyr::filter(stringr::str_detect(content, "^JEL CLASSIFICATION ")) |>
    dplyr::pull(content) |>
    stringr::str_remove('JEL CLASSIFICATION ') |>
    trimws()
  
  keywords <- blocks_tbl |>
    dplyr::filter(`page` == 1) |>
    dplyr::filter(stringr::str_detect(content, "^KEYWORDS")) |>
    dplyr::pull(content) |>
    stringr::str_remove('KEYWORDS') |>
    trimws()
  
  full_text <- blocks_tbl |> 
    dplyr::filter(`page`>0) |>
    dplyr::group_by(`page`) |>
    dplyr::mutate(row = 1:dplyr::n()) |>
    dplyr::mutate(header_footer = dplyr::case_when(
      page == 1 ~ row >= max(row)-2, 
      TRUE ~ row >= max(row)
    )) |>
    dplyr::ungroup() |>
    dplyr::filter(!header_footer) |>
    dplyr::summarise(text = paste(content, collapse = "\n")) |>
    dplyr::pull() 
  
  # if \n is followed by a lower case letter replace it with a space
  full_text <- stringr::str_replace_all(full_text, "\n([a-z])", " \\1")
  
  list(
    doi = doi,
    jel = jel,
    keywords = keywords,
    full_text = full_text
  )
  
}
