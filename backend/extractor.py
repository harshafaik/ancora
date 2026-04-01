import requests
import trafilatura
from trafilatura.metadata import extract_metadata

def extract_content(url):
    """
    Hits the URL and extracts clean body text and metadata using trafilatura.
    Returns a dict with 'text', 'title', and 'date'.
    """
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        
        text = trafilatura.extract(response.text)
        metadata = extract_metadata(response.text)
        
        if text:
            return {
                'text': text,
                'title': getattr(metadata, 'title', None) if metadata else None,
                'date': getattr(metadata, 'date', None) if metadata else None
            }
        return None
    except Exception as e:
        print(f"Extraction error for {url}: {e}")
        return None
