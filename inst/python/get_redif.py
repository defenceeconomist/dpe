# import redif file from repec ftp
from ftplib import FTP

def get_defpea_redif():
  uri = "ftp.repec.org"
  ftp = FTP(uri)
  ftp.login()
  
  ftp.cwd("/opt/ReDIF/RePEc/taf/defpea")
  
  # List contents
  files = ftp.nlst()
  
  with open("data-raw/repec/defpea.redif", "wb") as f:
    ftp.retrbinary(f"RETR defpea.redif", f.write)
  
  ftp.quit()
  return ("downloaded '/opt/ReDIF/RePEc/taf/defpea/defpea.redif' "
          "to 'data-raw/repec/defpea.redif")

  
  
