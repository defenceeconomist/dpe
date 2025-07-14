library(dpe)
db <- connect_postgres()
DBI::dbExecute(db, "CREATE DATABASE dpe;")
DBI::dbDisconnect(db)

 db <- DBI::dbConnect(
    RPostgres::Postgres(),
    user = Sys.getenv("POSTGRES_USER"),
    password = Sys.getenv("POSTGRES_PASSWORD"),
    host = "postgres",
    db = "dpe"
  )

data(dpe_vol_35)
head(dpe_vol_35)

DBI::dbWriteTable(conn = db, name = "dpe_summary_crossref", as.data.frame(dpe_vol_35), row.names = FALSE )

dpe_vol_35 |>
    jsonlite::toJSON()
