import os
import httpx
from google import genai

def get_crux(text, provider="Gemini", api_key=None, model=None):
    """
    Identifies the central argument or load-bearing claim using the selected provider.
    """
    if not api_key:
        return "Error: API Key not provided."

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
        if provider == "Gemini":
            client = genai.Client(api_key=api_key)
            model_id = model or "gemini-2.0-flash"
            response = client.models.generate_content(
                model=model_id,
                contents=prompt
            )
            return response.text.strip()

        else:
            # Groq, Mistral, and OpenRouter are all OpenAI-compatible
            base_urls = {
                "Groq": "https://api.groq.com/openai/v1",
                "Mistral": "https://api.mistral.ai/v1",
                "OpenRouter": "https://openrouter.ai/api/v1"
            }
            
            base_url = base_urls.get(provider)
            if not base_url:
                return f"Error: Unsupported provider {provider}"

            headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            }
            
            # OpenRouter requires extra headers
            if provider == "OpenRouter":
                headers["HTTP-Referer"] = "https://github.com/harshafaik/ancora"
                headers["X-Title"] = "Ancora"

            payload = {
                "model": model,
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "temperature": 0.1
            }

            with httpx.Client(timeout=30.0) as client:
                response = client.post(f"{base_url}/chat/completions", headers=headers, json=payload)
                response.raise_for_status()
                result = response.json()
                return result['choices'][0]['message']['content'].strip()

    except Exception as e:
        return f"Error getting crux via {provider}: {e}"
