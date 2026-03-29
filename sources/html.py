import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin

def discover_html(homepage_url, article_patterns=None, exclude_patterns=None):
    """
    Hits a homepage, extracts article URLs using BeautifulSoup.
    Allows for specific inclusion/exclusion patterns.
    """
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    article_patterns = article_patterns or []
    exclude_patterns = exclude_patterns or []
    
    try:
        response = requests.get(homepage_url, headers=headers, timeout=10)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.text, 'html.parser')
        links = set()
        
        for a in soup.find_all('a', href=True):
            full_url = urljoin(homepage_url, a['href'])
            
            # Simple discovery logic
            # 1. Must be on the same domain
            if homepage_url.split('//')[1].split('/')[0] in full_url:
                # 2. Must match at least one article pattern if provided
                if article_patterns:
                    if any(p in full_url for p in article_patterns):
                        if not any(e in full_url for e in exclude_patterns):
                            links.add(full_url)
                else:
                    # Default: try to avoid common noise if no patterns
                    if not any(e in full_url for e in exclude_patterns):
                        links.add(full_url)
                        
        return list(links)
            
    except Exception as e:
        print(f"HTML Discovery error for {homepage_url}: {e}")
        return []
