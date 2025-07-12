
#' Process DPE
#' 
#' Gadet to upload PDF files and return the aims, data, methods, findings, conclusions, doi, keywords and JEL codes.
#' 
#' @export
process_dpe_gadget <- function(){

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
      DT::DTOutput("table")
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

    output$table <- DT::renderDataTable(values$dataset)
    
    # loop through the uploaded data files and 
    # extract the doi, jel, keywords, full_text
    # and count the tokens in full_text.
    observeEvent(input$upload,{

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
      
      return(showModal(modalDialog(
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
      write.csv(values$dataset, file, row.names = FALSE)
    }
  )
    
  }
  shiny::runGadget(ui, server)
}

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
