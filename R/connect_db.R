connect_db <- function(){
  DBI::dbConnect(
    RPostgres::Postgres(),
    user = "rstudio",
    password = Sys.getenv("POSTGRES_PASSWORD"),
    db = "dpe",
    host = "postgres",
    port = 5432
  )
}