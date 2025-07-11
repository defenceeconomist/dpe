import pymupdf # PyMuPDF

def process_dpe_data(pdf_path):
  doc = pymupdf.open(pdf_path)
  cover = []
  block_text = []
  metadata = {}
  metadata['filepath'] = pdf_path
    
  for index in range(0, doc.page_count):
    page = doc.load_page(index)
   
    blocks = page.get_text("dict")["blocks"]
    for i, block in enumerate(blocks):
      
      if block['type'] == 0:  # type 0 = text block
          text = block['lines']
          full_text = ""
          for line in text:
              for span in line['spans']:
                  full_text += span['text'] + " "
         
          if index == 0: 
            cover.append(full_text.strip()) 
            doi_line = next((line for line in cover if line.startswith("To link") and "https://doi.org" in line), None)
            if doi_line:
              doi = doi_line.split("https://doi.org/")[-1].strip()
              metadata['doi'] = doi
          else:
            if index == 1:
              # extract the line in blocktext that starts KEYWORDS and save as key 'keywords' removing KEYWORDS
              keywords_line = next((line for line in block_text if line.startswith("KEYWORDS")), None)
              
              if keywords_line:
                keywords = keywords_line.replace("KEYWORDS", "").strip()
                metadata['keywords'] =  keywords
           
              # do the same for JEL
              jel_line = next((line for line in block_text if line.startswith("JEL CLASSIFICATION")), None)
              if jel_line:
                jel = jel_line.replace("JEL CLASSIFICATION", "").strip()
                metadata['jel'] = jel
            
              block_text.append(full_text.strip())
            else:
              block_text.append(full_text.strip())
      
  metadata['fulltext'] = block_text
  return metadata

