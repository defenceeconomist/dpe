#' Defence and Peace Economics Article Metadata
#'
#' A dataset containing bibliographic and analytical metadata for 61 articles published in *Defence and Peace Economics* (Volume 35, Issue 1). Each row corresponds to a unique article and includes bibliographic identifiers, author information, and summarised content extracted from the full text.
#'
#' @format A tibble with 61 rows and 18 variables:
#' \describe{
#'   \item{doi}{Character. Digital Object Identifier (DOI) of the article.}
#'   \item{volume}{Character. Journal volume number.}
#'   \item{issue}{Character. Journal issue number.}
#'   \item{page_start}{Numeric. First page of the article.}
#'   \item{page_end}{Numeric. Last page of the article.}
#'   \item{title}{Character. Title of the article.}
#'   \item{author}{List of tibbles. Detailed author metadata, including ORCID, name, affiliation, and sequence.}
#'   \item{url}{Character. Resolvable URL for the article (usually via DOI).}
#'   \item{published.print}{Character. Print publication date in YYYY-MM-DD format.}
#'   \item{aims}{Character. Summary of the article’s aims.}
#'   \item{data}{Character. Description of the data used.}
#'   \item{methods}{Character. Description of the research methods used.}
#'   \item{findings}{Character. Summary of the main findings.}
#'   \item{conclusions}{Character. Summary of the conclusions drawn.}
#'   \item{primary_theme}{Character. Thematically coded primary subject of the article.}
#'   \item{secondary_theme}{Character. Optionally coded secondary theme (if applicable).}
#'   \item{keywords}{Character. List of article keywords.}
#'   \item{jel}{Character. Journal of Economic Literature (JEL) classification codes.}
#' }
#'
#' @source Extracted and processed from published PDFs using the `dpe` package tools.
#'
#' @examples
#' data(dpe_vol_35)
#' dplyr::glimpse(dpe_vol_35)
#'
#' @docType data
#' @name dpe_vol_35
#' @keywords datasets
NULL

#' Defence and Peace Economics Theme Taxonomy
#'
#' A reference table of thematic categories used to classify articles in the field of defence and peace economics. Each theme includes a short description to guide consistent tagging and classification of research.
#'
#' @format A tibble with 23 rows and 2 variables:
#' \describe{
#'   \item{theme}{Character. The name of the theme (e.g., "Conflict & Civil Wars", "Terrorism").}
#'   \item{description}{Character. A brief summary of the scope and content covered by each theme.}
#' }
#'
#' @details
#' Themes are used throughout the `dpe` package to structure text extraction tasks, annotate research outputs, and support thematic coding in LLM-based workflows.
#'
#' @examples
#' data(dpe_themes)
#' dplyr::glimpse(dpe_themes)
#' dpe_themes$theme
#'
#' @source Manually curated based on editorial themes from the journal *Defence and Peace Economics*.
#'
#' @docType data
#' @name dpe_themes
#' @keywords datasets
NULL
