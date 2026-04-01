import sqlite3
import hashlib
from datetime import datetime, timezone
import os

DB_NAME = "ancora.db"

def get_connection():
    """Returns a connection to the SQLite database."""
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Creates tables if they do not exist."""
    with get_connection() as conn:
        cursor = conn.cursor()
        
        # Sources table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS sources (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                type TEXT NOT NULL, -- 'rss' or 'scrape'
                url TEXT NOT NULL,
                added_at TEXT NOT NULL,
                active INTEGER DEFAULT 1
            )
        """)
        
        # Articles table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS articles (
                id TEXT PRIMARY KEY, -- SHA256 hash of URL
                source TEXT NOT NULL,
                url TEXT UNIQUE NOT NULL,
                title TEXT,
                published_at TEXT,
                fetched_at TEXT NOT NULL,
                full_text TEXT,
                crux TEXT,
                crux_model TEXT
            )
        """)
        conn.commit()

def generate_id(url):
    """Generates a SHA256 hash of the URL to use as an ID."""
    return hashlib.sha256(url.encode('utf-8')).hexdigest()

def upsert_article(article_dict):
    """
    Inserts a new article or ignores if the URL already exists.
    Returns True if a new article was inserted, False otherwise.
    """
    url = article_dict['url']
    article_id = generate_id(url)
    fetched_at = article_dict.get('fetched_at') or datetime.now(timezone.utc).isoformat()
    
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT OR IGNORE INTO articles (
                id, source, url, title, published_at, fetched_at, full_text
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            article_id,
            article_dict['source'],
            url,
            article_dict.get('title'),
            article_dict.get('published_at'),
            fetched_at,
            article_dict.get('full_text')
        ))
        conn.commit()
        return cursor.rowcount > 0

def update_crux(url, crux, model_name):
    """Updates the crux of an article only if it's currently NULL."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE articles 
            SET crux = ?, crux_model = ?
            WHERE url = ? AND crux IS NULL
        """, (crux, model_name, url))
        conn.commit()

def get_unprocessed():
    """Returns articles where crux IS NULL."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM articles WHERE crux IS NULL")
        return [dict(row) for row in cursor.fetchall()]

def get_all_articles():
    """Returns all articles ordered by fetched_at DESC."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM articles ORDER BY fetched_at DESC")
        return [dict(row) for row in cursor.fetchall()]

def get_article_by_id(article_id):
    """Returns a single article by its SHA256 id."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM articles WHERE id = ?", (article_id,))
        row = cursor.fetchone()
        return dict(row) if row else None

def get_sources():
    """Returns all sources."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM sources ORDER BY added_at DESC")
        return [dict(row) for row in cursor.fetchall()]

def get_active_sources():
    """Returns only active sources."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM sources WHERE active = 1")
        return [dict(row) for row in cursor.fetchall()]

def add_source(source_dict):
    """Adds a new source."""
    source_id = generate_id(source_dict['url'])
    added_at = datetime.now(timezone.utc).isoformat()
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO sources (id, name, type, url, added_at, active)
            VALUES (?, ?, ?, ?, ?, 1)
        """, (source_id, source_dict['name'], source_dict['type'], source_dict['url'], added_at))
        conn.commit()
        return source_id

def toggle_source(source_id):
    """Toggles the active status of a source."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE sources SET active = 1 - active WHERE id = ?", (source_id,))
        conn.commit()

def delete_source(source_id):
    """Deletes a source."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM sources WHERE id = ?", (source_id,))
        conn.commit()

if __name__ == "__main__":
    # Self-test if run directly
    init_db()
    print("Database initialized.")
