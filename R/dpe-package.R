#' Defence and Peace Economics
#' 
#' Automated evidence synthesis from the journal of defence and peace economics.
#' 
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL

utils::globalVariables(c(".data", "count_tokens", "extract_blocks"))

.onAttach <- function(libname, pkgname) {
  packageStartupMessage("Run setup_python_env() before running `py_pdf_blocks` or `py_count_tokens`.")
}