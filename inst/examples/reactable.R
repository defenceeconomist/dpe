library(reactable)

dpe_detail_df <-readr::read_csv("data/2024_35_1_results.csv")
dpe_meta_df <- readr::read_csv("data/defpea_repec.csv") |>
  dplyr::select(
    `Author-Name`, 
    `Title`, 
    `Pages`,
    `Volume`, 
    `Issue`, 
    `Year`, 
    `X-DOI`, 
    `File-URL`
  )

dataset <- function(){
  
  dpe_df <- dpe_detail_df |>
    dplyr::left_join(dpe_meta_df, 
                     by = c("doi" = "X-DOI"))
  list(
    meta = dpe_df |>
      dplyr::select(
        "Title", "Author-Name", "Year", "Pages", "Issue", "Volume", "File-URL"
      ),
    detail = dpe_df |>
      dplyr::select(aims, data, methods, findings, conclusions, primary_theme, secondary_theme)
  )
}

tbl <- reactable(
  data = dataset()$meta |> dplyr::select(-`File-URL`), 
  columns = list(
    Title = colDef(cell = function(value, index){
      url <- dataset()$meta[index, "File-URL"] |> dplyr::pull()
      htmltools::tags$a(href = url, target = "_blank", value)
    }, minWidth = 300)
  ),
  details = function(x) row_details,
  wrap = FALSE, 
  class = "dpe-articles",
  rowStyle = list(cursor = "pointer"),
  theme = reactableTheme(cellPadding = "8px 12px")
)

div(class = "articles",
    h2(class = "title", "Defence and Peace Economics Articles"),
    renderReactable(tbl))
