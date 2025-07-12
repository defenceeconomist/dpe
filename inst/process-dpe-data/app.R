library(shiny)
library(dpe)
library(ellmer)
TOKEN_LIMIT = 100e3
options(shiny.maxRequestSize = 30 * 1024^2)

# Load themes
dpe_themes <- jsonlite::read_json("../../data/dpe_themes.json") |>
  purrr::list_flatten()

theme_labels <- purrr::map_chr(dpe_themes, ~.x$theme)
theme_descriptions <- purrr::map_chr(dpe_themes, ~.x$description)

ui <- fluidPage(
  sidebarLayout(
    sidebarPanel(
      fileInput(
        inputId = "upload",
        label = "upload",
        multiple = TRUE,
        accept = ".pdf"
      ),
      downloadButton("download")
    ),
    mainPanel(
      reactable::reactableOutput("table")
    )
  )
)

server <- function(input, output, session) {
  
  values <- reactiveValues(
    dataset = dplyr::tibble(
      doi = NA, 
      aims = NA, 
      data = NA, 
      method = NA, 
      findings = NA, 
      conclusions = NA,
      primary_theme = NA, 
      secondary_theme = NA,
      keywords = NA,
      jel = NA
    )
  )
  output$table <- reactable::renderReactable({
    reactable::reactable(
      values$dataset
    )
  })
  
  observeEvent(input$upload,{

    # loop through the uploaded data files and 
    # extract the doi, jel, keywords, full_text
    # and count the tokens in full_text.
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
    
    
   
    
    chat <- chat_openai(
      model = "gpt-4o",
      system_prompt = paste(
        "You are an English academic research assistant.",
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
    
    txt_list <- purrr::map(pdf_data, ~.x$full_text)
    
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

    
    values$dataset <- results_df
    

  })
  
  output$download <- downloadHandler(
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

shinyApp(ui, server)
