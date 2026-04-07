import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Manages a list of user-defined keyword alerts.
///
/// Articles whose title or crux contain any keyword are tagged in the feed.
class KeywordAlerts {
  static const String _key = 'keywordAlerts';

  /// Returns the current list of alert keywords.
  static Future<List<String>> getKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw));
    } catch (e) {
      return [];
    }
  }

  /// Save the keyword list.
  static Future<void> setKeywords(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(keywords));
  }

  /// Check if the given text matches any keyword.
  static bool matchesAny(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    return keywords.any((kw) => lower.contains(kw.toLowerCase()));
  }

  /// Returns the list of matching keywords for the given text.
  static List<String> getMatches(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    return keywords
        .where((kw) => lower.contains(kw.toLowerCase()))
        .toList();
  }
}
