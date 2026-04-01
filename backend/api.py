from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
import os

from db import get_all_articles, get_article_by_id, init_db, get_sources, add_source, toggle_source, delete_source
from main import run as run_ingestion

app = FastAPI(title="Ancora API")

# Enable CORS for all origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class Article(BaseModel):
    id: str
    source: str
    url: str
    title: Optional[str] = None
    published_at: Optional[str] = None
    fetched_at: str
    full_text: Optional[str] = None
    crux: Optional[str] = None
    crux_model: Optional[str] = None

class Source(BaseModel):
    id: str
    name: str
    type: str
    url: str
    added_at: str
    active: int

class SourceCreate(BaseModel):
    name: str
    url: str
    type: str = "rss"

class IngestRequest(BaseModel):
    provider: Optional[str] = "Gemini"
    api_key: Optional[str] = None
    model: Optional[str] = None

class IngestResponse(BaseModel):
    new_articles: int
    new_cruxes: int

@app.on_event("startup")
def startup_event():
    init_db()

@app.get("/articles", response_model=List[Article])
def get_articles():
    return get_all_articles()

@app.get("/articles/{article_id}", response_model=Article)
def get_article(article_id: str):
    article = get_article_by_id(article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")
    return article

@app.get("/sources", response_model=List[Source])
def list_sources():
    return get_sources()

@app.post("/sources", response_model=dict)
def create_source(source: SourceCreate):
    try:
        source_id = add_source(source.dict())
        return {"id": source_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.patch("/sources/{source_id}/toggle")
def toggle_source_endpoint(source_id: str):
    toggle_source(source_id)
    return {"status": "success"}

@app.delete("/sources/{source_id}")
def delete_source_endpoint(source_id: str):
    delete_source(source_id)
    return {"status": "success"}

@app.post("/ingest", response_model=IngestResponse)
def trigger_ingest(request: IngestRequest):
    try:
        results = run_ingestion(
            provider=request.provider,
            api_key=request.api_key,
            model=request.model
        )
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("api:app", host="0.0.0.0", port=8000, reload=True)
