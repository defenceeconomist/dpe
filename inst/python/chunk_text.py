# Chunk the text
import tiktoken

def chunk_text(text, max_tokens=3000, overlap=200):
    enc = tiktoken.encoding_for_model("gpt-4")
    words = text.split()
    chunks = []
    start = 0

    while start < len(words):
        chunk = words[start:start+max_tokens]
        token_count = len(enc.encode(" ".join(chunk)))
        while token_count > max_tokens:
            chunk = chunk[:-100]  # back off
            token_count = len(enc.encode(" ".join(chunk)))

        chunks.append(" ".join(chunk))
        start += max_tokens - overlap

    return chunks
