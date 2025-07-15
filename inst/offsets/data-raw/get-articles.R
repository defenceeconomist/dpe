library(dpe)
library(Microsoft365R)
library(rcrossref)
setup_python_env()

od <- get_personal_onedrive()

volume_uri <- "Articles/offsets"

articles <- od$list_files(volume_uri) 


tmp_dir <- tempdir(check = TRUE)
for(i in 1:nrow(articles)){
  od$download_file(srcid = articles$id[i], dest = file.path(tmp_dir, articles$name[i]), overwrite = TRUE)
}

datapath <- file.path(tmp_dir, list.files(tmp_dir, pattern = ".pdf$"))
filename <- purrr::map_chr(stringr::str_split(datapath, "/"), ~.x[length(.x)])

pdfdata <- purrr::pmap(
    list(datapath = datapath, 
        name = filename),
    function(datapath, name){
        fulltext <- paste(purrr::map(py_pdf_blocks(datapath), ~.x$content), collapse = "\n")
        tokens <- py_count_tokens(fulltext)
      list(fulltext = fulltext, tokens = tokens)
    })

# Process with Ellmer
TOKEN_LIMIT = 100e3

if(any(purrr::map_dbl(pdfdata, ~.x$tokens) > TOKEN_LIMIT)){
  
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
    "Output all results with UK British English spelling."
  )
)

schema <- ellmer::type_object(
  .description = "Extract the aims, data, methods, findings, conclusions and DOI from this article.",
  aims          = ellmer::type_string("The research aims", required = FALSE),
  data          = ellmer::type_string("The data used", required = FALSE),
  methods       = ellmer::type_string("The methodology used", required = FALSE),
  findings      = ellmer::type_string("The findings", required = FALSE),
  conclusions   = ellmer::type_string("The conclusions of the paper", required = FALSE),
  doi = ellmer::type_string("The doi number of the article.", required = FALSE)
  )


txt_list <- purrr::map(pdfdata, ~.x$fulltext)

results_df <- ellmer::parallel_chat_structured(
  chat,
  txt_list,
  type = schema
)
which(is.na(results_df$doi))
datapath[which(is.na(results_df$doi))]
results_df$doi[9] <- "10.1080/10430719808404896"
results_df <- results_df[-13, ]

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

saveRDS(crossref_pdf, "offsets-papers-v1.RDS")
