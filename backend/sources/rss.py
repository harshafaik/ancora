import feedparser

def discover_rss(rss_url):
    """
    Parses an RSS feed and returns a list of article links.
    """
    try:
        feed = feedparser.parse(rss_url)
        return [entry.link for entry in feed.entries if 'link' in entry]
    except Exception as e:
        print(f"RSS Discovery error for {rss_url}: {e}")
        return []
