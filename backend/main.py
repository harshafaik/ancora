from dotenv import load_dotenv
load_dotenv()

from sources.rss import discover_rss
from sources.html import discover_html
from extractor import extract_content
from crux import get_crux
from db import init_db, upsert_article, get_unprocessed, update_crux, get_active_sources, get_sources, add_source
import os

DEFAULT_CONFIG = [
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
    }
]

def run(provider="Gemini", api_key=None, model=None):
    # 1. Initialize DB
    init_db()
    
    # Use environment fallback for backward compatibility if not provided via API
    # This specifically helps the manual 'python main.py' runs
    current_api_key = api_key or os.environ.get("GOOGLE_API_KEY")
    current_model = model or ("gemini-2.0-flash" if provider == "Gemini" else None)
    
    # Ensure some sources exist
    if not get_sources():
        for source in DEFAULT_CONFIG:
            add_source(source)
    
    active_sources = get_active_sources()
    
    new_articles_count = 0
    new_cruxes_count = 0
    
    # 2. Ingest Articles from active sources
    for source in active_sources:
        print(f"--- Processing source: {source['name']} ({source['url']}) ---")
        
        links = []
        if source['type'] == 'rss':
            links = discover_rss(source['url'])
        elif source['type'] == 'html':
            links = discover_html(
                source['url'], 
                article_patterns=source.get('article_patterns', ["/article/", "/latest/"]),
                exclude_patterns=source.get('exclude_patterns', [])
            )
        
        # Limit to 5 for now
        for link in links[:5]:
            print(f"Fetching content for: {link}")
            extracted = extract_content(link)
            
            if extracted and extracted.get('text'):
                article_data = {
                    "source": source['name'],
                    "url": link,
                    "title": extracted.get('title'),
                    "published_at": extracted.get('date'),
                    "full_text": extracted.get('text')
                }
                if upsert_article(article_data):
                    new_articles_count += 1
                    print(f"Upserted: {article_data['title']}")
                else:
                    print(f"Skipped (already exists): {article_data['title']}")
            else:
                print(f"Failed to extract content for: {link}")

    # 3. Process Crux for unprocessed articles
    unprocessed = get_unprocessed()
    print(f"\n--- Found {len(unprocessed)} unprocessed articles. Generating crux via {provider}... ---")
    
    for article in unprocessed:
        print(f"Crux for: {article['title']} ({article['url']})")
        crux_text = get_crux(
            article['full_text'], 
            provider=provider, 
            api_key=current_api_key, 
            model=current_model
        )
        
        if crux_text and not crux_text.startswith("Error"):
            update_crux(article['url'], crux_text, current_model or provider)
            new_cruxes_count += 1
            print("Successfully updated crux in DB.")
        else:
            print(f"Failed to generate crux: {crux_text}")
            
    return {
        "new_articles": new_articles_count,
        "new_cruxes": new_cruxes_count
    }

if __name__ == "__main__":
    run()
