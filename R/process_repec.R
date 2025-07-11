parse_redif <- function(redif_file){
  repec <- readLines(redif_file) |> 
    paste(collapse = "\n")
  
  repec_list <- stringr::str_split(repec, "\n\n")[[1]]
  repec_list <- repec_list[!repec_list == ""]
  
  parsed_repec <- purrr::map(repec_list, ~{
    stringr::str_split(.x, "\n") |>
      purrr::pluck(1) |>
      dplyr::as_tibble() |>
      dplyr::mutate(group = cumsum(stringr::str_detect(value, "^\\s", negate = TRUE))) |>
      dplyr::group_by(group) |>
      dplyr::summarise(value = paste(value, collapse = "")) |>
      dplyr::mutate(key = trimws(substr(value, 1, stringr::str_locate(value, ":")-1)),
                    value = trimws(substr(value, stringr::str_locate(value, ":")+1, nchar(value)))) |>
      dplyr::select(key, value) 
  })
}