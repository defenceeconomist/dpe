#' Connect to Database
#'@export
connect_postgres <- function(){
  DBI::dbConnect(
    RPostgres::Postgres(),
    user = Sys.getenv("POSTGRES_USER"),
    password = Sys.getenv("POSTGRES_PASSWORD"),
    host = "postgres",
    db = Sys.getenv("POSTGRES_DB")
  )
}
