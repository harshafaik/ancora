import os
from google import genai


def get_crux(text):
    """
    Identifies the central argument or load-bearing claim of the article.
    Returns 2-3 sentences max.
    """
    api_key = os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        return "Error: GOOGLE_API_KEY environment variable not set."

    client = genai.Client(api_key=api_key)
    model_id = "gemini-3-flash-preview"

    prompt = f"""
    Analyze the following article text. Your goal is NOT to provide a summary of its contents. 
    Instead, identify the single most important load-bearing claim or central argument the author is making. 
    What is the crux of this piece? 
    
    Constraints:
    - Maximum 2-3 sentences.
    - Focus on the 'why' or the 'so what' of the piece, not just the 'what'.
    - Be precise and direct.
    - DO NOT use meta-phrases like 'The article argues', 'The author claims', 'This piece contends', or 'The crux is'. 
    - State the claim directly as a standalone assertion.

    Article Text:
    {text}
    """

    try:
        response = client.models.generate_content(model=model_id, contents=prompt)
        return response.text.strip()
    except Exception as e:
        return f"Error getting crux: {e}"
