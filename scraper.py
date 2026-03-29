import requests
import trafilatura
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import feedparser

def discover_rss_feeds(rss_url):
    """
    Parses an RSS feed using feedparser and extracts all article URLs.
    """
    try:
        feed = feedparser.parse(rss_url)
        links = []
        for entry in feed.entries:
            if 'link' in entry:
                links.append(entry.link)
        
        print(f"--- Discovered {len(links)} articles from RSS: {rss_url} ---")
        for link in sorted(links):
            print(link)
        return links
    except Exception as e:
        print(f"Error parsing RSS feed {rss_url}: {e}")
        return []

def discover_feeds(homepage_url):
    """
    Hits the homepage, extracts all article URLs using BeautifulSoup, 
    and filters out non-article links.
    """
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(homepage_url, headers=headers, timeout=10)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.text, 'html.parser')
        links = set()
        
        # Scroll.in articles typically have /article/ or /video/ or /latest/ in the URL
        for a in soup.find_all('a', href=True):
            href = a['href']
            # Convert relative URLs to absolute
            full_url = urljoin(homepage_url, href)
            
            # Filter for Scroll.in articles (avoiding common noise like social/about links)
            if 'scroll.in/article/' in full_url or 'scroll.in/latest/' in full_url:
                if '#' not in full_url: # ignore anchor links
                    links.add(full_url)
        
        print(f"--- Discovered {len(links)} articles from {homepage_url} ---")
        for link in sorted(links):
            print(link)
        return list(links)
            
    except Exception as e:
        print(f"Error discovering Scroll feeds: {e}")
        return []

def discover_wire_feeds(homepage_url):
    """
    Hits The Wire homepage and extracts article URLs using BeautifulSoup.
    """
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(homepage_url, headers=headers, timeout=10)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'html.parser')
        
        filtered_links = set()
        for a in soup.find_all('a', href=True):
            full_url = urljoin(homepage_url, a['href'])
            if 'thewire.in/' in full_url:
                path = full_url.replace('https://thewire.in/', '').strip('/')
                parts = path.split('/')
                exclude = ['about-us', 'terms-of-use', 'privacy-policy', 'contact-us', 'category', 'tag', 'author', 'wp-content', 'wp-json']
                if len(parts) >= 2 and not any(x == parts[0] for x in exclude):
                    filtered_links.add(full_url)
        
        print(f"--- Discovered {len(filtered_links)} articles from {homepage_url} ---")
        for link in sorted(filtered_links):
            print(link)
        return list(filtered_links)
            
    except Exception as e:
        print(f"Error discovering Wire feeds: {e}")
        return []

def scrape_article(url):
    """
    Hits the URL, pulls HTML, and extracts clean body text using trafilatura.
    """
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        
        # Extract text from HTML
        downloaded = response.text
        result = trafilatura.extract(downloaded)
        
        if result:
            print(f"--- Content from {url} ---\n")
            print(result)
            print("\n--- End of Content ---")
        else:
            print(f"Failed to extract content from {url}")
            
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    # 1. Discovery from Scroll.in (HTML parsing)
    # print("--- SCROLL.IN DISCOVERY ---")
    # scroll_links = discover_feeds("https://scroll.in")
    # print("\n")

    # 2. Discovery from The Wire (trafilatura fallback)
    # print("--- THE WIRE DISCOVERY ---")
    # wire_links = discover_wire_feeds("https://thewire.in")
    # print("\n")

    # 3. Discovery from The Hindu (RSS feed)
    print("--- THE HINDU RSS DISCOVERY ---")
    hindu_rss_url = "https://www.thehindu.com/news/national/feeder/default.rss"
    hindu_links = discover_rss_feeds(hindu_rss_url)
    print("\n")

    # Test extraction on one from each if found
    # if scroll_links:
    #     print("--- Testing extraction: Scroll ---")
    #     scrape_article(scroll_links[0])
    #     print("\n")

    if hindu_links:
        print("--- Testing extraction: The Hindu ---")
        scrape_article(hindu_links[0])

