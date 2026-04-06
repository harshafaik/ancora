import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../models/default_prompts.dart';
import '../widgets/concept_explanation_sheet.dart';
import '../widgets/web_view_screen.dart';
import '../services/ai_service.dart';
import '../services/database_helper.dart';

/// Displays a single article with interactive concept highlighting,
/// typography controls (font size + family), and the Crux section.
class ArticleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> article;
  final double fontSize;
  final String fontFamily;
  final Function(double) onFontSizeChanged;
  final Function(String) onFontFamilyChanged;

  const ArticleDetailScreen({
    super.key,
    required this.article,
    required this.fontSize,
    required this.fontFamily,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late double _localFontSize;
  late String _localFontFamily;
  List<String> _concepts = [];
  bool _isRegenerating = false;

  /// Available font families with display labels.
  static const List<Map<String, String>> _fontOptions = [
    {'label': 'Roboto', 'family': 'Roboto', 'category': 'system'},
    {'label': 'Lora', 'family': 'Lora', 'category': 'serif'},
    {'label': 'Merriweather', 'family': 'Merriweather', 'category': 'serif'},
    {'label': 'Source Serif', 'family': 'SourceSerif4', 'category': 'serif'},
    {'label': 'DM Sans', 'family': 'DMSans', 'category': 'sans'},
    {'label': 'Plus Jakarta', 'family': 'PlusJakartaSans', 'category': 'sans'},
    {'label': 'Fraunces', 'family': 'Fraunces', 'category': 'display'},
  ];

  @override
  void initState() {
    super.initState();
    _localFontSize = widget.fontSize;
    _localFontFamily = widget.fontFamily;
    _parseConcepts();
  }

  void _parseConcepts() {
    if (widget.article['concepts'] == null) return;
    try {
      _concepts = List<String>.from(jsonDecode(widget.article['concepts']));
    } catch (e) {
      print('Error parsing concepts: $e');
    }
  }

  /// Opens the concept explanation sheet for a highlighted term.
  Future<void> _showConceptDetails(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('apiProvider') ?? 'Gemini';
    final apiKey = prefs.getString('apiKey') ?? '';
    final model = prefs.getString('apiModel') ??
        (provider == 'Gemini' ? 'gemini-2.0-flash' : '');
    final customPrompt =
        prefs.getString('explanationPrompt') ?? DefaultPrompts.explanation;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A1A)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ConceptExplanationSheet(
        term: term,
        contextText: widget.article['title'] ?? '',
        provider: provider,
        apiKey: apiKey,
        model: model,
        customPrompt: customPrompt,
      ),
    );
  }

  /// Builds rich text with interactive concept highlights (underlined, tappable).
  Widget _buildInteractiveText(
    String text, {
    required TextStyle style,
    bool isHeading = false,
  }) {
    if (_concepts.isEmpty || isHeading) {
      return Text(text, style: style);
    }

    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final sortedConcepts = List<String>.from(_concepts)
      ..sort((a, b) => b.length.compareTo(a.length));

    int currentPos = 0;
    while (currentPos < text.length) {
      int nextMatchStart = -1;
      String matchedConcept = '';

      for (var concept in sortedConcepts) {
        if (concept.isEmpty) continue;
        final index = lowerText.indexOf(concept.toLowerCase(), currentPos);
        if (index != -1 &&
            (nextMatchStart == -1 || index < nextMatchStart)) {
          nextMatchStart = index;
          matchedConcept =
              text.substring(index, index + concept.length);
        }
      }

      if (nextMatchStart != -1) {
        if (nextMatchStart > currentPos) {
          spans.add(
              TextSpan(text: text.substring(currentPos, nextMatchStart)));
        }

        spans.add(
          TextSpan(
            text: matchedConcept,
            style: style.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showConceptDetails(matchedConcept),
          ),
        );
        currentPos = nextMatchStart + matchedConcept.length;
      } else {
        spans.add(TextSpan(text: text.substring(currentPos)));
        break;
      }
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
    );
  }

  /// Opens the article's original URL in a WebView.
  void _openWebView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          url: widget.article['url'],
          title: widget.article['source'] ?? 'Original Article',
        ),
      ),
    );
  }

  /// Regenerates the crux using the AI service.
  Future<void> _regenerateCrux() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('apiProvider') ?? 'Gemini';
    final apiKey = prefs.getString('apiKey') ?? '';
    final model = prefs.getString('apiModel') ??
        (provider == 'Gemini' ? 'gemini-2.0-flash' : '');
    final customCruxPrompt = prefs.getString('cruxPrompt');

    if (apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No API key configured. Set one in API Settings.'),
        ),
      );
      return;
    }

    final fullText = widget.article['full_text']?.toString() ?? '';
    if (fullText.isEmpty || fullText.length < 100) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Article text is too short to generate a crux.'),
        ),
      );
      return;
    }

    setState(() => _isRegenerating = true);

    final ai = AiService();
    final result = await ai.getCruxAndConcepts(
      text: fullText,
      provider: provider,
      apiKey: apiKey,
      model: model,
      promptTemplate: customCruxPrompt,
    );

    if (!mounted) return;

    setState(() => _isRegenerating = false);

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Crux generation failed: ${result['error']}')),
      );
      return;
    }

    if (result.containsKey('crux')) {
      final crux = result['crux'];
      final concepts = jsonEncode(result['concepts'] ?? []);
      await DatabaseHelper().updateCrux(
        widget.article['url'],
        crux,
        model.isNotEmpty ? model : provider,
        concepts: concepts,
      );

      // Update local article data
      widget.article['crux'] = crux;
      widget.article['concepts'] = concepts;
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crux updated.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected AI response — no crux found.')),
      );
    }
  }

  /// Shares the article's crux, title, and source via the system share sheet.
  void _shareCrux() {
    final crux = widget.article['crux'];
    final title = widget.article['title'] ?? 'Untitled';
    final source = widget.article['source'] ?? '';

    if (crux == null || crux.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No crux available to share.')),
      );
      return;
    }

    final text = '$title\n— $source\n\n$crux';
    Share.share(text, subject: title);
  }

  /// Calculates reading time in minutes at ~200 wpm.
  int _readingTimeMinutes() {
    final text = widget.article['full_text']?.toString() ?? '';
    if (text.isEmpty) return 0;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (words / 200).ceil();
  }

  /// Splits raw article text into display-ready paragraphs.
  ///
  /// Strategy:
  /// 1. Split on `\n\n` or `\n` (preserves trafilatura's paragraph breaks).
  /// 2. Only for truly massive single-line blobs (> 2000 chars, 0 newlines),
  ///    falls back to sentence-level splitting.
  List<String> _splitIntoParagraphs(String text) {
    final rawLines = text.split('\n');
    final nonEmpty = rawLines.where((l) => l.trim().isNotEmpty).toList();

    // If text is a single massive blob with no line breaks, split at sentences.
    if (nonEmpty.length <= 1 && text.length > 2000) {
      return _splitAtSentences(text);
    }

    // Otherwise trust the paragraph structure from trafilatura.
    return nonEmpty.map((l) => l.trim()).toList();
  }

  /// Splits a blob of text at sentence boundaries.
  List<String> _splitAtSentences(String text) {
    // Match sentence endings: punctuation + space(s) + uppercase start of
    // next sentence, OR just punctuation at end of string.
    final parts = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);

      // Check for sentence-ending punctuation followed by space.
      if (i + 2 < text.length) {
        final current = text[i];
        final next = text[i + 1];
        final after = text[i + 2];

        if ((current == '.' || current == '!' || current == '?') &&
            next == ' ' &&
            (after.toUpperCase() == after || after == '"' || after == '(' ||
                after == '"')) {
          parts.add(buffer.toString().trim());
          buffer.clear();
        }
      }
    }

    // Flush remaining.
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString().trim());
    }

    return parts.where((s) => s.isNotEmpty).toList();
  }

  /// Strips markdown formatting from text that came from trafilatura.
  /// Removes `**bold**`, `*italic*`, `_italic_`, `~~strikethrough~~`,
  /// and link/image syntax while preserving the text content.
  static String _stripMarkdown(String text) {
    String result = text;
    // Bold/italic: **text**, *text*, __text__, _text_
    result = result.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    result = result.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
    result = result.replaceAll(RegExp(r'__(.+?)__'), r'$1');
    result = result.replaceAll(RegExp(r'_(.+?)_'), r'$1');
    // Strikethrough
    result = result.replaceAll(RegExp(r'~~(.+?)~~'), r'$1');
    // Links: [text](url) → text
    result = result.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    // Images: ![alt](url) → alt
    result = result.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), r'$1');
    // Inline code: `code`
    result = result.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // HTML tags that might have survived
    result = result.replaceAll(RegExp(r'<[^>]+>'), '');
    // Clean up double spaces
    result = result.replaceAll(RegExp(r'  +'), ' ');
    return result.trim();
  }

  /// Returns a TextStyle using the user-selected font family.
  TextStyle _bodyTextStyle({
    required double fontSize,
    required double height,
    required FontWeight fontWeight,
    Color? color,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: _localFontFamily,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      color: color,
      fontStyle: fontStyle,
    );
  }

  /// Bottom sheet combining font size slider and font family picker.
  void _showFontDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Typography',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Font Size',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('A', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _localFontSize,
                      min: 12,
                      max: 30,
                      divisions: 18,
                      onChanged: (value) {
                        setModalState(() => _localFontSize = value);
                        setState(() => _localFontSize = value);
                        widget.onFontSizeChanged(value);
                      },
                    ),
                  ),
                  const Text('A', style: TextStyle(fontSize: 24)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Font Family',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _fontOptions.map((font) {
                  final isSelected =
                      _localFontFamily == font['family'];
                  return ChoiceChip(
                    label: Text(
                      font['label']!,
                      style: TextStyle(
                        fontFamily: font['family'],
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setModalState(
                            () => _localFontFamily = font['family']!);
                        setState(
                            () => _localFontFamily = font['family']!);
                        widget.onFontFamilyChanged(font['family']!);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String fullText = widget.article['full_text']?.toString() ?? '';
    final List<String> paragraphs = _splitIntoParagraphs(fullText);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareCrux,
            tooltip: 'Share Crux',
          ),
          IconButton(
            icon: const Icon(Icons.format_size_rounded),
            onPressed: _showFontDialog,
            tooltip: 'Typography',
          ),
          IconButton(
            icon: const Icon(Icons.web_rounded),
            onPressed: _openWebView,
            tooltip: 'Open Web View',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                widget.article['title'] ?? 'No Title',
                style: TextStyle(
                  fontSize: _localFontSize + 6,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              // Source, date & reading time
              Row(
                children: [
                  Text(
                    widget.article['source'] ?? 'Unknown Source',
                    style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  if (widget.article['published_at'] != null &&
                      widget.article['published_at']
                              .toString()
                              .length >=
                          10) ...[
                    const SizedBox(width: 8),
                    Text('•',
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(width: 8),
                    Text(
                      widget.article['published_at'].substring(0, 10),
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ],
              ),
              if (_readingTimeMinutes() > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '${_readingTimeMinutes()} min read',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Crux section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF121212)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'THE CRUX',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white60),
                        ),
                        if (widget.article['full_text'] != null &&
                            widget.article['full_text']
                                    .toString()
                                    .length >=
                                100)
                          IconButton(
                            icon: _isRegenerating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 20),
                            onPressed:
                                _isRegenerating ? null : _regenerateCrux,
                            tooltip: 'Regenerate Crux',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.article['crux'] ?? 'No crux generated yet.',
                      style: _bodyTextStyle(
                        fontSize: _localFontSize,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Body or failure message
              if (widget.article['extraction_status'] == 'failed') ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error
                          .withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.link_off_rounded,
                        size: 56,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Content unavailable',
                        style: TextStyle(
                          fontSize: _localFontSize + 2,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This article requires JavaScript rendering or '
                        'could not be fetched. Open it in your browser '
                        'to read the full content.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _localFontSize - 2,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openWebView,
                          icon: const Icon(
                            Icons.open_in_browser_rounded,
                            size: 22,
                          ),
                          label: Text(
                            'Open in Browser — ${widget.article['source'] ?? 'Article'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            elevation: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (widget.article['extraction_status'] == 'partial')
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Colors.orangeAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orangeAccent, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only a partial version of this article is available.',
                            style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...paragraphs.map((p) {
                  String trimmed = p.trim();
                  if (trimmed.isEmpty) return const SizedBox.shrink();

                  // Strip markdown syntax (**bold**, *italic*, etc.)
                  trimmed = _stripMarkdown(trimmed);

                  bool isHeading = false;
                  double size = _localFontSize;
                  FontWeight weight = FontWeight.w400;
                  String displayContent = trimmed;

                  if (trimmed.startsWith('### ')) {
                    isHeading = true;
                    size = _localFontSize + 2;
                    weight = FontWeight.bold;
                    displayContent = trimmed.substring(4);
                  } else if (trimmed.startsWith('## ')) {
                    isHeading = true;
                    size = _localFontSize + 4;
                    weight = FontWeight.bold;
                    displayContent = trimmed.substring(3);
                  } else if (trimmed.startsWith('# ')) {
                    isHeading = true;
                    size = _localFontSize + 6;
                    weight = FontWeight.bold;
                    displayContent = trimmed.substring(2);
                  }

                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: isHeading ? 12.0 : 20.0,
                        top: isHeading ? 16.0 : 0.0),
                    child: _buildInteractiveText(
                      displayContent,
                      isHeading: isHeading,
                      style: _bodyTextStyle(
                        fontSize: size,
                        height: isHeading ? 1.3 : 1.8,
                        fontWeight: weight,
                        color: Theme.of(context).brightness ==
                                Brightness.dark
                            ? (isHeading
                                ? Colors.white
                                : Colors.grey[300])
                            : (isHeading
                                ? Colors.black
                                : Colors.black87),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
