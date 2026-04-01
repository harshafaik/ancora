import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  Future<Map<String, dynamic>> getCruxAndConcepts({
    required String text,
    required String provider,
    required String apiKey,
    required String model,
    String? promptTemplate,
  }) async {
    if (apiKey.isEmpty) return {"error": "API Key not provided."};

    final defaultPrompt = """
Analyze the following article text. Your goal is to:
1. Identify the single most important load-bearing claim (the Crux).
2. Identify "Unexplained Dependencies"—specialized concepts, acronyms, or systemic terms that the author invokes as foundational to their argument but does not define for the reader. 

Return your response in EXACTLY this JSON format:
{
  "crux": "2-3 sentences stating the central argument directly.",
  "concepts": ["Concept 1", "Concept 2"]
}

Constraints for Concepts:
- ONLY pick terms that are essential to understanding the author's logic.
- Avoid generic words.
- If the author explains the term in the text, DO NOT include it.
- Max 5 terms.

Article Text:
{{text}}
""";

    String prompt = promptTemplate ?? defaultPrompt;
    // Handle both {{text}} and old style $text if user tried to copy-paste
    prompt = prompt.replaceAll("{{text}}", text).replaceAll("\$text", text);

    try {
      String responseBody = "";
      if (provider == "Gemini") {
        final url = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey";
        final response = await http.post(
          Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [
              {
                "parts": [{"text": prompt}]
              }
            ],
            "generationConfig": {
              "response_mime_type": "application/json"
            }
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          responseBody = data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
        } else {
          return {"error": "Gemini API returned ${response.statusCode}"};
        }
      } else {
        // Groq, Mistral, OpenRouter
        final Map<String, String> baseUrls = {
          "Groq": "https://api.groq.com/openai/v1",
          "Mistral": "https://api.mistral.ai/v1",
          "OpenRouter": "https://openrouter.ai/api/v1"
        };

        final baseUrl = baseUrls[provider];
        final headers = {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json"
        };

        final payload = {
          "model": model,
          "messages": [{"role": "user", "content": prompt}],
          "temperature": 0.1,
          "response_format": {"type": "json_object"}
        };

        final response = await http.post(Uri.parse("$baseUrl/chat/completions"), headers: headers, body: jsonEncode(payload));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          responseBody = data['choices'][0]['message']['content'].toString().trim();
        } else {
          return {"error": "$provider API returned ${response.statusCode}"};
        }
      }

      // Clean up response if it has markdown code blocks
      if (responseBody.contains("```json")) {
        responseBody = responseBody.split("```json")[1].split("```")[0].trim();
      } else if (responseBody.contains("```")) {
        responseBody = responseBody.split("```")[1].split("```")[0].trim();
      }

      print('AI RAW RESPONSE: $responseBody');
      final decoded = jsonDecode(responseBody);
      return decoded;
    } catch (e) {
      print('AI SERVICE ERROR: $e');
      return {"error": "AI error: $e"};
    }
  }

  Future<String> getConceptExplanation({
    required String concept,
    required String articleContext,
    required String provider,
    required String apiKey,
    required String model,
    String? promptTemplate,
  }) async {
    final defaultPrompt = """
You are a reading companion. The user is reading an article and encountered the term "{{term}}".
Explain this concept briefly (2-4 sentences) and specifically contextualize how it relates to the following article context:

"{{context}}"

Your goal is to help the reader understand the "knowledge delta"—what they need to know about this term to fully grasp the author's inference.
""";

    String prompt = promptTemplate ?? defaultPrompt;
    prompt = prompt
        .replaceAll("{{term}}", concept)
        .replaceAll("{{context}}", articleContext)
        .replaceAll("\$concept", concept)
        .replaceAll("\$articleContext", articleContext);

    try {
      if (provider == "Gemini") {
        final url = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey";
        final response = await http.post(
          Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [{"parts": [{"text": prompt}]}]
          }),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
        }
      } else {
        // OpenAI-compatible
        final Map<String, String> baseUrls = {
          "Groq": "https://api.groq.com/openai/v1",
          "Mistral": "https://api.mistral.ai/v1",
          "OpenRouter": "https://openrouter.ai/api/v1"
        };
        final baseUrl = baseUrls[provider];
        final response = await http.post(
          Uri.parse("$baseUrl/chat/completions"),
          headers: {
            "Authorization": "Bearer $apiKey",
            "Content-Type": "application/json"
          },
          body: jsonEncode({
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.3
          }),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'].toString().trim();
        }
      }
      return "Unable to generate explanation at this time.";
    } catch (e) {
      return "Error: $e";
    }
  }
}
