library(Microsoft365R)
library(dpe)
library(rcrossref)
setup_python_env()

# Download Folder from OneDrive ---
od <- get_personal_onedrive()

volume_uri <- "Data/dpe/2021"
dir <- od$list_files(volume_uri) |>
  dplyr::filter(isdir)

volume_pdf <- purrr::map_df(dir$name, function(d) od$list_files(file.path(volume_uri, d)))
volume_pdf

tmp_dir <- tempdir(check = TRUE)
for(i in 1:nrow(volume_pdf)){
  od$download_file(srcid = volume_pdf$id[i], dest = file.path(tmp_dir, volume_pdf$name[i]))
}

datapath <- file.path(tmp_dir, list.files(tmp_dir, pattern = ".pdf$"))
filename <- purrr::map_chr(stringr::str_split(datapath, "/"), ~.x[length(.x)])

# Extract the PDF Data ---
pdf_data <- purrr::pmap(
      list(datapath = datapath, 
           name = filename),
      function(datapath, name){
        # process pdf_data
        pdf_data <- py_pdf_blocks(datapath) |> 
          process_blocks()
        # count tokens
        append(
          pdf_data, list(
            tokens = purrr::pluck(pdf_data, "full_text") |>  py_count_tokens(),
            filename = name
            )
        )
      }
    )

# Process with Ellmer
TOKEN_LIMIT = 100e3
data(dpe_themes)

if(any(purrr::map_dbl(pdf_data, ~.x$tokens) > TOKEN_LIMIT)){
  
  # loop through pdf_data and return filename if token exceed token limit 
  exceeded_pdf <- purrr::map_lgl(pdf_data, ~.x$tokens> TOKEN_LIMIT)
  exceeded_files <- purrr::map_chr(pdf_data[exceeded_pdf], ~.x$filename)
  
  error_msg <- glue::glue(
    "Files: {paste(exceeded_files, collapse = ', ')} ",
    "have exceeded the token limit of {TOKEN_LIMIT}. "
    )
  
  stop(
    error_msg
  )
}

chat <- ellmer::chat_openai(
  model = "gpt-4o",
  system_prompt = paste(
    "You are an English academic research assistant.",
    "Extract aims, data, methods, findings, conclusions.",
    "Then assign:",
    "- primary_theme: the single main theme from the list:",
    paste0("* ", dpe::dpe_themes$theme, ": ", dpe::dpe_themes$description, collapse = "\n"),
    "- secondary_theme: another relevant theme if one exists, otherwise null.",
    "Return JSON that exactly matches the schema."
  )
)

schema <- ellmer::type_object(
  aims          = ellmer::type_string(required = FALSE),
  data          = ellmer::type_string(required = FALSE),
  methods       = ellmer::type_string(required = FALSE),
  findings      = ellmer::type_string(required = FALSE),
  conclusions   = ellmer::type_string(required = FALSE),
  primary_theme = ellmer::type_enum(
    description = paste(
      "Select the single most appropriate main theme from:", 
      paste(dpe::dpe_themes$theme, collapse = ", ")
    ),
    values = as.character(dpe::dpe_themes$theme)
  ),
  secondary_theme = ellmer::type_enum(
    description = paste(
      "Optionally select a secondary theme (or return null) from:", 
      paste(dpe::dpe_themes$theme, collapse = ", ")
    ),
    values = as.character(dpe::dpe_themes$theme),
    required = FALSE
  )
)

txt_list <- purrr::map(pdf_data, ~.x$full_text)

results_df <- ellmer::parallel_chat_structured(
  chat,
  txt_list,
  type = schema
)

# Add other meta data
results_df$doi <- purrr::map_chr(pdf_data, ~{
if (length(.x$doi) == 0) NA_character_ else .x$doi
})

results_df$keywords <- purrr::map_chr(pdf_data, ~{
if (length(.x$keywords) == 0) NA_character_ else .x$keywords
})

results_df$jel <- purrr::map_chr(pdf_data, ~{
if (length(.x$jel) == 0) NA_character_ else .x$jel
})

# Add DOIs with Cross Ref

dois <- results_df |>
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
  dplyr::left_join(results_df, by = "doi") 

dpe_vol_32 <- crossref_pdf
usethis::use_data(dpe_vol_32)
unlink(tmp_dir, recursive = TRUE)
