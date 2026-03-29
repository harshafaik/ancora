from dotenv import load_dotenv
load_dotenv()

from sources.rss import discover_rss
from sources.html import discover_html
from extractor import extract_content
from crux import get_crux

CONFIG = [
    {
        "name": "The Hindu Editorial",
        "type": "rss",
        "url": "https://www.thehindu.com/opinion/editorial/feeder/default.rss"
    },
    {
        "name": "The Hindu National",
        "type": "rss",
        "url": "https://www.thehindu.com/news/national/feeder/default.rss"
    },
    {
        "name": "Scroll",
        "type": "html",
        "url": "https://scroll.in",
        "article_patterns": ["/article/", "/latest/"]
    },
    {
        "name": "The Wire",
        "type": "html",
        "url": "https://thewire.in",
        "exclude_patterns": ["about-us", "terms-of-use", "privacy-policy", "contact-us", "category", "tag", "author"]
    }
]

def run():
    # Use the first configured source (now The Hindu Editorial)
    source = CONFIG[0]
    print(f"--- Fetching from {source['name']} ({source['url']}) ---")
    
    links = discover_rss(source['url'])
    
    if links:
        target_url = links[0]
        print(f"--- Target Article: {target_url} ---\n")
        
        content = extract_content(target_url)
        
        if content:
            print("--- FULL ARTICLE TEXT ---")
            print(content)
            print("\n" + "-"*30 + "\n")
            
            print("--- THE CRUX ---")
            crux = get_crux(content)
            print(crux)
        else:
            print("Failed to extract content.")
    else:
        print("No articles found in feed.")

if __name__ == "__main__":
    run()
