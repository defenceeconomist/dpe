
def extract_from_chunk(client, chunk):
    prompt = f"""From the following text, extract the aim, method, findings, and conclusion (if any). Output as JSON: {chunk}"""
    response = client.responses.create(
        model= "gpt-4.1",
        input= prompt
    )
    return response
  
def synthesis(client, responses):

  # Combine them and summarise
  synthesis_prompt = f"""You are provided with several JSON objects containing partial extractions from different sections of a paper.
  Combine them into a single consistent JSON with four fields: aim, method, findings, and conclusion. Resolve any duplication or inconsistency.
  
  Data:
  {responses}
  """

  final_response = client.responses.create(
          model= "gpt-4.1",
          input= synthesis_prompt
      )
      
  return final_response
