
library(RPostgres)
db <- DBI::dbConnect(
  RPostgres::Postgres(),
  user = "rstudio",
  password = Sys.getenv("POSTGRES_PASSWORD"),
  db = "rstudio_db",
  host = "postgres",
  port = 5432
)

dbExecute(db, "CREATE DATABASE dpe;")

DBI::dbDisconnect(db)
db <- DBI::dbConnect(
  RPostgres::Postgres(),
  user = "rstudio",
  password = Sys.getenv("POSTGRES_PASSWORD"),
  db = "dpe",
  host = "postgres",
  port = 5432
)

sql <- DBI::sqlInterpolate(db, "CREATE TABLE IF NOT EXISTS gpt_summary (
    doi TEXT,
    objective TEXT,
    data TEXT,
    methods TEXT,
    findings TEXT,
    conclusions TEXT
);")

DBI::dbExecute(db,sql)

sql <- DBI::sqlInterpolate(db, "CREATE TABLE IF NOT EXISTS dpe_meta (
    doi TEXT,
    keywords TEXT,
    jel TEXT,
    filename TEXT
);")

DBI::dbExecute(db,sql)


db |>
  dplyr::tbl("gpt_summary")
