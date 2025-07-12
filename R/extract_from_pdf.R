#' Interactive PDF Extractor for DPE Summaries
#'
#' Launches a Shiny gadget to upload and process academic PDFs related to
#' Defence and Peace Economics (DPE). It extracts structured metadata
#' including aims, data, methods, findings, conclusions, keywords, DOI,
#' JEL codes, and themes using a large language model.
#'
#' @details
#' The gadget:
#' \itemize{
#'   \item Accepts multiple PDF files.
#'   \item Uses Python functions (`py_pdf_blocks`, `py_count_tokens`) to extract raw content.
#'   \item Applies an OpenAI GPT model via the `ellmer` package to extract structured fields.
#'   \item Automatically checks for token limits and alerts the user if exceeded.
#'   \item Displays a reactive summary table and allows the result to be downloaded as CSV.
#' }
#'
#' Requires a working Python environment and properly configured `reticulate`, `ellmer`, and `dpe` packages.
#'
#' @note 
#' Files exceeding 100,000 tokens will not be processed.
#'
#' @return
#' A `tibble` containing the extracted data, returned when the gadget is closed with the "Done" button.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' extract_from_pdf()
#' }
extract_from_pdf <- function(){

  setup_python_env()
  TOKEN_LIMIT = 100e3
  options(shiny.maxRequestSize = 30 * 1024^2)

  ui <- miniUI::miniPage(
    miniUI::gadgetTitleBar("Process DPE PDF Data"),
    miniUI::miniContentPanel(
      shiny::fileInput(
        inputId = "upload",
        label = "Upload PDF(s)",
        multiple = TRUE, 
        accept = "application/pdf"
      ),
      shiny::dataTableOutput("table")
    ),
    miniUI::miniButtonBlock(
      shiny::downloadButton("download")
    )
  )

  server <- function(input, output, session){

    values <- shiny::reactiveValues(
      dataset = dplyr::tibble(
        doi = NA,
        aims = NA,
        data = NA,
        methods = NA,
        findings = NA,
        conclusions = NA,
        primary_theme = NA,
        secondary_theme = NA, 
        keywords = NA,
        jel = NA
      )
    )

    shiny::observeEvent(input$done, {
      returnValue <- values$dataset
      shiny::stopApp(returnValue)
    })

    output$table <- shiny::renderDataTable(values$dataset)
    
    # loop through the uploaded data files and 
    # extract the doi, jel, keywords, full_text
    # and count the tokens in full_text.
    shiny::observeEvent(input$upload,{

    pdf_data <- purrr::pmap(
      list(datapath = input$upload$datapath, 
           name = input$upload$name),
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
    
    # throw an error message if any of the uploaded files exceed the file limit.
    if(any(purrr::map_dbl(pdf_data, ~.x$tokens) > TOKEN_LIMIT)){
      
      # loop through pdf_data and return filename if token exceed token limit 
      exceeded_pdf <- purrr::map_lgl(pdf_data, ~.x$tokens> TOKEN_LIMIT)
      exceeded_files <- purrr::map_chr(pdf_data[exceeded_pdf], ~.x$filename)
      
      error_msg <- glue::glue(
        "Files: {paste(exceeded_files, collapse = ', ')} ",
        "have exceeded the token limit of {TOKEN_LIMIT}. "
        )
      
      return(shiny::showModal(shiny::modalDialog(
        title = "Error: Token Limit Exceeded",
        error_msg
      )))
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
  
    results_df$doi <- purrr::map_chr(pdf_data, ~{
    if (length(.x$doi) == 0) NA_character_ else .x$doi
    })

    results_df$keywords <- purrr::map_chr(pdf_data, ~{
    if (length(.x$keywords) == 0) NA_character_ else .x$keywords
    })

    results_df$jel <- purrr::map_chr(pdf_data, ~{
    if (length(.x$jel) == 0) NA_character_ else .x$jel
    })
      
    values$dataset <- results_df
    })

    output$download <- shiny::downloadHandler(
    filename = function(){
      today <- Sys.Date() |>
        stringr::str_remove_all("-")
      glue::glue("{today}-dpe-summary.csv")
    }, 
    content = function(file){
      utils::write.csv(values$dataset, file, row.names = FALSE)
    }
  )
    
  }
  shiny::runGadget(ui, server)
}

#' Extract pdf blocks 
#' 
#' Use pymupdf to extract text blocks from pdf document
#' 
#' @param filepath path to pdf file
#' 
#' @return pdf text
#' 
#'@examples
#' \dontrun{
#'   py_pdf_blocks("paper.pdf")
#' }
#'@export
py_pdf_blocks <- function(filepath){
  reticulate::source_python(system.file("python/process_article.py", package = "dpe"))
  extract_blocks(filepath)
}


#' Count Tokens in Text Using Python's `tiktoken`
#'
#' Counts the number of tokens in a given text string using the `tiktoken` Python package. This is useful for estimating token usage when interacting with language models such as GPT-4.
#'
#' @param x A character string. The text for which token count should be calculated.
#'
#' @details
#' This function acts as a wrapper for a Python function `count_tokens()` defined in `count_tokens.py`, which must be located in the `inst/python/` directory of the `dpe` package. The Python script should be compatible with the `tiktoken` library and support the model intended for use.
#'
#' Internally, the function uses `reticulate::source_python()` to source the Python script and call `count_tokens(x)`.
#'
#' @return A numeric value representing the number of tokens in the input text.
#'
#' @examples
#' \dontrun{
#' py_pdf_blocks("paper.pdf") |>
#'   process_blocks() |>
#'   purrr::pluck("full_text") |>
#'   py_count_tokens()
#' }
#'
#' @export
py_count_tokens <- function(x){
  reticulate::source_python(system.file("python/count_tokens.py", package = "dpe"))
  count_tokens(x) 
}

#' Process Extracted PDF Blocks into Structured Metadata
#'
#' Converts a list of text blocks (typically extracted from a PDF using a tool like `py_pdf_blocks`) into structured metadata fields: DOI, JEL codes, keywords, and full text.
#'
#' @param pdf_blocks A list of named lists or tibbles, where each element represents a block of text from a page in a PDF document. Each block must include at least `page` and `content` fields.
#'
#' @details
#' This function:
#' \itemize{
#'   \item Parses the DOI from page 0 using a regex pattern that detects standard DOI formats.
#'   \item Extracts JEL classification codes and keywords from page 1.
#'   \item Removes headers and footers from body pages to produce a clean `full_text` field.
#'   \item Normalises line breaks within paragraphs by replacing `\n` followed by a lowercase letter with a space.
#' }
#'
#' @return A named list with the following elements:
#' \describe{
#'   \item{doi}{A character string containing the document DOI (or `NA` if not found).}
#'   \item{jel}{A character string of JEL classification codes (or `NA`).}
#'   \item{keywords}{A character string of keywords (or `NA`).}
#'   \item{full_text}{A single string containing the cleaned full text content of the document body.}
#' }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' blocks <- py_pdf_blocks("paper.pdf")
#' result <- process_blocks(blocks)
#' result$doi
#' result$full_text
#' }
process_blocks <- function(pdf_blocks){
  blocks_tbl <- pdf_blocks |>
    purrr::map_df(~.x) 
  
  # regular expression to extract the text after doi.org/
  # - ([0-9]{2}): matches two digits
  # - \\. : matches a literal dot
  # - [0-9a-zA-Z.-]+: matches one or more alphanumeric characters, dots, or hyphens (the rest of the DOI)
  
  doi_regex <- "([0-9]{2}\\.[0-9]+/[0-9a-zA-Z.-]+)" 
  doi <- blocks_tbl |>
    dplyr::filter(.data$page == 0) |>
    dplyr::filter(stringr::str_detect(.data$`content`, "^To link to this")) |>
    dplyr::pull(.data$`content`) |>
    stringr::str_extract(doi_regex)
  
  jel <- blocks_tbl |>
    dplyr::filter(.data$`page` == 1) |>
    dplyr::filter(stringr::str_detect(.data$`content`, "^JEL CLASSIFICATION ")) |>
    dplyr::pull(.data$`content`) |>
    stringr::str_remove('JEL CLASSIFICATION ') |>
    trimws()
  
  keywords <- blocks_tbl |>
    dplyr::filter(.data$`page` == 1) |>
    dplyr::filter(stringr::str_detect(.data$`content`, "^KEYWORDS")) |>
    dplyr::pull(.data$`content`) |>
    stringr::str_remove('KEYWORDS') |>
    trimws()
  
  full_text <- blocks_tbl |> 
    dplyr::filter(.data$`page`>0) |>
    dplyr::group_by(.data$`page`) |>
    dplyr::mutate(`row` = 1:dplyr::n()) |>
    dplyr::mutate(`header_footer` = dplyr::case_when(
      .data$`page` == 1 ~ .data$`row` >= max(.data$`row`)-2, 
      TRUE ~ .data$`row` >= max(.data$`row`)
    )) |>
    dplyr::ungroup() |>
    dplyr::filter(!.data$`header_footer`) |>
    dplyr::summarise(text = paste(.data$`content`, collapse = "\n")) |>
    dplyr::pull() 
  
  # if \n is followed by a lower case letter replace it with a space
  full_text <- stringr::str_replace_all(.data$`full_text`, "\n([a-z])", " \\1")
  
  list(
    doi = doi,
    jel = jel,
    keywords = keywords,
    full_text = full_text
  )
  
}
