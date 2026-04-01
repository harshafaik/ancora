## Ancora - Current State
- **RSS ingestion**: working (The Hindu)
- **HTML scraping**: working (Scroll.in)
- **Crux extraction**: working (Gemini API - gemini-3-flash-preview)
- **Next**: persistence layer

## Key decisions
- **Python backend**: Focus on speed of development and library support (trafilatura, feedparser, BS4).
- **Gemini API for crux**: Explicitly tuned to identify the load-bearing claim rather than a generic summary.
- **No database yet**: Initial priority is reliable extraction and analysis before permanent storage.
- **Modular structure**: Separate handlers for RSS and HTML to allow for easy scaling.
