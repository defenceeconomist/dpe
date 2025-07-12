
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

This will return the resulting data to a variable in your current session.

You can then match this to meta data from cross ref using:

```{r}
extract_with_meta <- collect_meta_data(pdf_extract, "doi")
```

Finally, upload the results to a database with

```{r}
upload_to_database(extract_with_meta, db, "dpe_text_extract")
```


