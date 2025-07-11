library(reticulate)

# load R and python functions
for (file in list.files("py")) source_python(file.path("inst/python", file))
for (file in list.files("R")) source(file.path("R", file))


# load and process data in folder
dir <- "data-raw/onedrive/2024 35 1/"
pdf_data <- file.path(dir, list.files(dir)) |>
  purrr::map(~{
    pdf_data <- extract_blocks(.x) |> process_blocks() 
    append(
      pdf_data, list(
        tokens = purrr::pluck(pdf_data, "full_text") |>
          count_tokens())
      )
  })

txt <- pdf_data[[1]]$full_text
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

result <- chat$chat_structured(
  txt,
  type = schema,
  echo = "none",
  convert = TRUE
)

results_df <- parallel_chat_structured(
  chat,
  txt_list,
  type = schema
)

results_df$doi <- purrr::map_chr(pdf_data, ~.x$doi)
results_df$keywords <- purrr::map_chr(pdf_data, ~.x$keywords)
results_df$jel <- purrr::map_chr(pdf_data, ~ifelse(is.null(.x$jel), NA, .x$jel))
write.csv(results_df, "data/2024_35_1_results.csv", row.names = FALSE)
