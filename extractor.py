import requests
import trafilatura

def extract_content(url):
    """
    Hits the URL and extracts clean body text using trafilatura.
    """
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        
        result = trafilatura.extract(response.text)
        return result
    except Exception as e:
        print(f"Extraction error for {url}: {e}")
        return None
