# Ancora

Ancora is a focused news discovery and analysis tool designed to extract the "crux" of articles from major Indian news sources. It identifies the central, load-bearing claim of a piece rather than providing a simple summary.

## Features
- **Multi-Source Discovery**: Supports RSS (The Hindu) and HTML scraping (Scroll.in).
- **Clean Extraction**: Leverages `trafilatura` for high-quality body text extraction.
- **Crux Identification**: Uses Google's Gemini API (`gemini-3-flash-preview`) to isolate the core argument of an article in 2-3 sentences.
- **Modular Architecture**: Separate modules for discovery and extraction logic.

## Getting Started

### Prerequisites
- Python 3.10+
- Google Gemini API Key

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/harshafaik/ancora.git
   cd ancora
   ```
2. Create and activate a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Configure environment:
   Create a `.env` file in the root directory:
   ```text
   GOOGLE_API_KEY=your_gemini_api_key_here
   ```

## Usage
Run the main script to discover and analyze the latest articles:
```bash
python main.py
```

## Project Documentation
Detailed project state and decisions can be found in [docs/CONTEXT.md](docs/CONTEXT.md).
