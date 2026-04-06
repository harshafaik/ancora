/// Returns true if two strings are semantically similar based on
/// stemmed word overlap. Used for title deduplication.
bool isVerySimilar(String s1, String s2, {double threshold = 0.6}) {
  if (s1.isEmpty || s2.isEmpty) return false;

  String n1 = s1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
  String n2 = s2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');

  if (n1 == n2) return true;

  String stem(String word) {
    if (word.length <= 3) return word;
    if (word.endsWith('ing')) return word.substring(0, word.length - 3);
    if (word.endsWith('s')) return word.substring(0, word.length - 1);
    if (word.endsWith('ed')) return word.substring(0, word.length - 2);
    return word;
  }

  final words1 = n1.split(RegExp(r'\s+')).where((w) => w.length > 2).map(stem).toSet();
  final words2 = n2.split(RegExp(r'\s+')).where((w) => w.length > 2).map(stem).toSet();

  if (words1.isEmpty || words2.isEmpty) return false;

  final intersection = words1.intersection(words2).length;
  final maxLen = words1.length > words2.length ? words1.length : words2.length;

  return (intersection / maxLen) >= threshold;
}

/// Removes redundant headers from the start of the article body that match the title.
String sanitizeArticleBody(String body, String title) {
  if (body.isEmpty || title.isEmpty || title == 'No Title') return body;

  List<String> paragraphs = body.split('\n\n');
  int removeCount = 0;

  for (var p in paragraphs) {
    final trimmed = p.trim();
    if (trimmed.isEmpty) continue;

    final contentOnly = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').trim();

    if (isVerySimilar(contentOnly, title)) {
      if (!trimmed.startsWith('#') && contentOnly.length > title.length * 1.8) {
        break;
      }
      removeCount++;
    } else if (trimmed.startsWith('#') && contentOnly.length < (title.length * 0.5)) {
      removeCount++;
    } else {
      break;
    }
  }

  if (removeCount > 0) {
    return paragraphs.skip(removeCount).join('\n\n');
  }
  return body;
}
