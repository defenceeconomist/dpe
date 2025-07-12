library(dpe)
library(ellmer)
setup_python_env()

# load and process data in folder
dir <- "data-raw/vol-35-pdfs/2024 35 7/"
pdf_data <- file.path(dir, list.files(dir)) |>
  purrr::map(~{
    pdf_data <- py_pdf_blocks(.x) |> process_blocks() 
    append(
      pdf_data, list(
        tokens = purrr::pluck(pdf_data, "full_text") |>
          py_count_tokens())
      )
  })

txt_list <- purrr::map(pdf_data, ~.x$full_text)

# count the number of tokens
# if the tokens exceed 128k then will need to chunk the text.
max(purrr::map_dbl(pdf_data, ~.x$tokens)) 


# load themes
dpe_themes <- jsonlite::read_json("data/dpe_themes.json") |>
  purrr::list_flatten()

theme_labels <- purrr::map_chr(dpe_themes, ~.x$theme)
theme_descriptions <- purrr::map_chr(dpe_themes, ~.x$description)


chat <- chat_openai(
  model = "gpt-4o",
  system_prompt = paste(
    "You are an academic research assistant.",
    "Extract aims, data, methods, findings, conclusions.",
    "Then assign:",
    "- primary_theme: the single main theme from the list:",
    paste0("* ", theme_labels, ": ", theme_descriptions, collapse = "\n"),
    "- secondary_theme: another relevant theme if one exists, otherwise null.",
    "Return JSON that exactly matches the schema."
  )
)

schema <- type_object(
  aims          = type_string(required = FALSE),
  data          = type_string(required = FALSE),
  methods       = type_string(required = FALSE),
  findings      = type_string(required = FALSE),
  conclusions   = type_string(required = FALSE),
  primary_theme = type_enum(
    description = paste(
      "Select the single most appropriate main theme from:", 
      paste(theme_labels, collapse = ", ")
    ),
    values = as.character(theme_labels)
  ),
  secondary_theme = type_enum(
    description = paste(
      "Optionally select a secondary theme (or return null) from:", 
      paste(theme_labels, collapse = ", ")
    ),
    values = as.character(theme_labels),
    required = FALSE
  )
)

results_df <- parallel_chat_structured(
  chat,
  txt_list,
  type = schema
)

results_df$doi <- purrr::map_chr(pdf_data, ~{
if (length(.x$doi) == 0) NA_character_ else .x$doi
})

results_df$keywords <- purrr::map_chr(pdf_data, ~{
if (length(.x$keywords) == 0) NA_character_ else .x$keywords
})

results_df$jel <- purrr::map_chr(pdf_data, ~{
if (length(.x$jel) == 0) NA_character_ else .x$jel
})

write.csv(results_df, "data-raw/dpe-summary/2024_35_7_results.csv", row.names = FALSE)
