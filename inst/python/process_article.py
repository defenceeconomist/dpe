import pymupdf

def extract_blocks(pdf_path):
  doc = pymupdf.open(pdf_path)
  
  block_text = []
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
        out = full_text.strip().replace("\x00", "")
        block_text.extend([{'page': index, 'content': out}])
      
  return block_text

