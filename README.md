
# dpe

<!-- badges: start -->
<!-- badges: end -->

The goal of dpe is to automatically synthesis evidence from the journal of defence and peace economics.

## Installation 

You can install the package from github using 

```{r}
devtools::install_github("defenceeconomist/dpe")
```

## Usage 

Extract the doi, aims, data, method, findings, conclusions, keywords and jel classifications from the pdf file using the following function.

```{r}
library(dpe)
setup_python_env() # install required python package (pymupdf and tiktoken)
pdf_extract <- extract_from_pdf()
```
