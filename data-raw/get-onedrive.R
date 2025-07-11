library(Microsoft365R)

od <- get_personal_onedrive(auth_type="device_code")
od$list_items(path = "data/dpe")

tmp_dir <- "data-raw/onedrive"

od$download_folder(srcid = "254B1551F6BADEE9!s48bebb0ac1c848829cf2c02721192ade", dest = tmp_dir)
list.files(tmp_dir, pattern = ".pdf$")
