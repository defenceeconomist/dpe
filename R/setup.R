#' Setup Python Environment
#' 
#' Creates and configures a virtualenv or conda env and installs required Python packages.
#' 
#' @param method Either "virtualenv" or "conda"
#' @param envname Name of the environment
#' @export
setup_python_env <- function(method = "virtualenv", envname = "r-myenv") {
  if (method == "virtualenv") {
    reticulate::virtualenv_create(envname)
  } else {
    reticulate::conda_create(envname)
  }

  reticulate::use_virtualenv(envname, required = TRUE)
  install_package_requirements("dpe", envname)
}

install_package_requirements <- function(pkg, env = NULL) {
  
  if (!is.null(env)) {
    if (grepl("conda", env)) reticulate::use_condaenv(env, required = TRUE)
    else reticulate::use_virtualenv(env, required = TRUE)
  }

  py_exe <- reticulate::py_config()$python
  req_file <- system.file("python/requirements.txt", package = pkg)
  if (req_file == "") stop("requirements.txt not found in package: ", pkg)
  
  system2(py_exe, c("-m", "pip", "install", "-r", shQuote(req_file)))
}