class DefaultPrompts {
  static const String crux = """
You are a careful reader. Given the article below, identify:

1. CRUX: The single load-bearing claim the entire piece depends on. 
Not a summary. Not the topic. The specific argument that, if removed, 
collapses the article's reasoning. One to three sentences, stated 
plainly.

Return only valid JSON:
{"crux": "...", "concepts": []}

Article Text:
{{text}}
""";

  static const String explanation = """
You are a reading companion. The user is reading an article and encountered the term "{{term}}".
Explain this concept briefly (2-4 sentences) and specifically contextualize how it relates to the following article context:

"{{context}}"

Your goal is to help the reader understand the "knowledge delta"—what they need to know about this term to fully grasp the author's inference.
""";
}
