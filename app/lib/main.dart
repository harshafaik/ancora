import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'services/database_helper.dart';
import 'services/news_service.dart';
import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AncoraApp());
}

const String baseUrl = 'http://192.168.29.209:8000';

class DefaultPrompts {
  static const String crux = """
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

  static const String explanation = """
You are a reading companion. The user is reading an article and encountered the term "{{term}}".
Explain this concept briefly (2-4 sentences) and specifically contextualize how it relates to the following article context:

"{{context}}"

Your goal is to help the reader understand the "knowledge delta"—what they need to know about this term to fully grasp the author's inference.
""";
}

class AncoraApp extends StatefulWidget {
  const AncoraApp({super.key});

  @override
  State<AncoraApp> createState() => _AncoraAppState();
}

class _AncoraAppState extends State<AncoraApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  double _fontSize = 17.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 2; // Default to dark
    final savedFontSize = prefs.getDouble('fontSize') ?? 17.0;
    setState(() {
      _themeMode = ThemeMode.values[themeIndex];
      _fontSize = savedFontSize;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
      prefs.setInt('themeMode', _themeMode.index);
    });
  }

  Future<void> _updateFontSize(double newSize) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = newSize;
      prefs.setDouble('fontSize', newSize);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Ancora',
          themeMode: _themeMode,
          theme: ThemeData(
            colorScheme: lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkDynamic ?? ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.black,
            cardTheme: const CardThemeData(
              color: Color(0xFF1A1A1A),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          home: FeedScreen(
            onThemeToggle: _toggleTheme, 
            currentThemeMode: _themeMode,
            fontSize: _fontSize,
            onFontSizeChanged: _updateFontSize,
          ),
        );
      },
    );
  }
}

class FeedScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final ThemeMode currentThemeMode;
  final double fontSize;
  final Function(double) onFontSizeChanged;

  const FeedScreen({
    super.key, 
    required this.onThemeToggle, 
    required this.currentThemeMode,
    required this.fontSize,
    required this.onFontSizeChanged,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final NewsService _newsService = NewsService();

  List<dynamic> _allArticles = [];
  List<dynamic> _filteredArticles = [];
  List<dynamic> _sources = [];
  String _selectedSource = 'All';
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadFromDb(); // Load cached data instantly
    _runBackgroundIngestion(); // Fetch new news in background
  }

  Future<void> _loadFromDb() async {
    try {
      final articles = await _db.getAllArticles();
      final sources = await _db.getSources();
      
      final activeSourceNames = sources
          .where((s) => s['active'] == 1)
          .map((s) => s['name'] as String)
          .toSet();

      setState(() {
        _allArticles = articles.where((a) => activeSourceNames.contains(a['source'])).toList();
        _sources = sources;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load database: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _runBackgroundIngestion() async {
    try {
      await _newsService.runIngestion();
      await _loadFromDb();
    } catch (e) {
      print('Background ingestion failed: $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    await _newsService.runIngestion();
    await _loadFromDb();
  }

  void _applyFilter() {
    if (_selectedSource == 'All') {
      _filteredArticles = _allArticles;
    } else {
      _filteredArticles = _allArticles.where((a) => a['source'] == _selectedSource).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ancora', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(widget.currentThemeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onThemeToggle,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : null,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.newspaper, size: 48),
                  SizedBox(height: 8),
                  Text('Ancora', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_input_component_outlined),
            title: const Text('Manage Sources'),
            onTap: () async {
              Navigator.pop(context); // Close drawer
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SourcesScreen()),
              );
              _loadFromDb();
            },
          ),
          ListTile(
            leading: const Icon(Icons.api_rounded),
            title: const Text('API Settings'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ApiSettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.terminal_rounded),
            title: const Text('Prompt Settings'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PromptSettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage_rounded),
            title: const Text('Database Viewer'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DatabaseViewerScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              showAboutDialog(
                context: context,
                applicationName: 'Ancora',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.newspaper, size: 48),
                children: [
                  const Text('Ancora is a minimal news reader that uses AI to extract the "Crux" of every article, saving you time.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    if (_sources.isEmpty && !_isLoading) return const SizedBox.shrink();
    
    final activeSourceNames = _sources
        .where((s) => s['active'] == 1)
        .map((s) => s['name'] as String)
        .toList();
    
    final filterOptions = ['All', ...activeSourceNames];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filterOptions.length,
        itemBuilder: (context, index) {
          final name = filterOptions[index];
          final isSelected = _selectedSource == name;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(name),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedSource = name;
                    _applyFilter();
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _allArticles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty && _allArticles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_filteredArticles.isEmpty) {
      return const Center(child: Text('No articles found.'));
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        itemCount: _filteredArticles.length,
        itemBuilder: (context, index) {
          final article = _filteredArticles[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArticleDetailScreen(
                    article: article,
                    fontSize: widget.fontSize,
                    onFontSizeChanged: widget.onFontSizeChanged,
                  ),
                ),
              );
            },
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['source'] ?? 'Unknown Source',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article['title'] ?? 'No Title',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (article['crux'] != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        article['crux'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[300], height: 1.5, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ArticleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> article;
  final double fontSize;
  final Function(double) onFontSizeChanged;

  const ArticleDetailScreen({
    super.key, 
    required this.article,
    required this.fontSize,
    required this.onFontSizeChanged,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final AiService _aiService = AiService();
  late double _localFontSize;
  List<String> _concepts = [];

  @override
  void initState() {
    super.initState();
    _localFontSize = widget.fontSize;
    if (widget.article['concepts'] != null) {
      try {
        _concepts = List<String>.from(jsonDecode(widget.article['concepts']));
      } catch (e) {
        print('Error parsing concepts: $e');
      }
    }
  }

  void _showConceptDetails(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('apiProvider') ?? 'Gemini';
    final apiKey = prefs.getString('apiKey') ?? '';
    final model = prefs.getString('apiModel') ?? (provider == 'Gemini' ? 'gemini-2.0-flash' : '');
    final customPrompt = prefs.getString('explanationPrompt') ?? DefaultPrompts.explanation;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _ConceptExplanationSheet(
        term: term,
        contextText: widget.article['title'] ?? '',
        provider: provider,
        apiKey: apiKey,
        model: model,
        customPrompt: customPrompt,
      ),
    );
  }

  Widget _buildInteractiveText(String text, {required TextStyle style, bool isHeading = false}) {
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
      String matchedConcept = "";

      for (var concept in sortedConcepts) {
        if (concept.isEmpty) continue;
        final index = lowerText.indexOf(concept.toLowerCase(), currentPos);
        if (index != -1 && (nextMatchStart == -1 || index < nextMatchStart)) {
          nextMatchStart = index;
          matchedConcept = text.substring(index, index + concept.length);
        }
      }

      if (nextMatchStart != -1) {
        if (nextMatchStart > currentPos) {
          spans.add(TextSpan(text: text.substring(currentPos, nextMatchStart)));
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
            recognizer: TapGestureRecognizer()..onTap = () => _showConceptDetails(matchedConcept),
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

  void _showFontSizeDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Adjust Font Size', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String fullText = widget.article['full_text']?.toString() ?? '';
    final List<String> paragraphs = fullText
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.format_size_rounded),
            onPressed: _showFontSizeDialog,
            tooltip: 'Adjust Font Size',
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
              Text(
                widget.article['title'] ?? 'No Title',
                style: TextStyle(
                  fontSize: _localFontSize + 6, 
                  fontWeight: FontWeight.bold, 
                  height: 1.2
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    widget.article['source'] ?? 'Unknown Source',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  if (widget.article['published_at'] != null && widget.article['published_at'].toString().length >= 10) ...[
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(width: 8),
                    Text(
                      widget.article['published_at'].substring(0, 10),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF121212) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THE CRUX',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white60),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.article['crux'] ?? 'No crux generated.',
                      style: TextStyle(
                        fontSize: _localFontSize,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (widget.article['extraction_status'] == 'failed') ...[
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.link_off_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Full text could not be extracted.',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _openWebView,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text('Read on ${widget.article['source']}'),
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
                      color: Colors.orangeAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only a partial version of this article is available.',
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...paragraphs.map((p) {
                  final String trimmed = p.trim();
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
                    padding: EdgeInsets.only(bottom: isHeading ? 12.0 : 20.0, top: isHeading ? 16.0 : 0.0),
                    child: _buildInteractiveText(
                      displayContent,
                      isHeading: isHeading,
                      style: TextStyle(
                        fontSize: size,
                        height: isHeading ? 1.3 : 1.8,
                        fontWeight: weight,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? (isHeading ? Colors.white : Colors.grey[300]) 
                            : (isHeading ? Colors.black : Colors.black87),
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

class _ConceptExplanationSheet extends StatefulWidget {
  final String term;
  final String contextText;
  final String provider;
  final String apiKey;
  final String model;
  final String customPrompt;

  const _ConceptExplanationSheet({
    super.key, 
    required this.term, 
    required this.contextText,
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.customPrompt,
  });

  @override
  State<_ConceptExplanationSheet> createState() => _ConceptExplanationSheetState();
}

class _ConceptExplanationSheetState extends State<_ConceptExplanationSheet> {
  final AiService _ai = AiService();
  String? _explanation;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchExplanation();
  }

  Future<void> _fetchExplanation() async {
    try {
      final explanation = await _ai.getConceptExplanation(
        concept: widget.term,
        articleContext: widget.contextText,
        provider: widget.provider,
        apiKey: widget.apiKey,
        model: widget.model,
        promptTemplate: widget.customPrompt,
      );
      
      setState(() {
        _explanation = explanation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to generate explanation.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONTEXTUAL EXPLANATION',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.blueAccent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.term,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(_error!, style: const TextStyle(color: Colors.grey)),
              )
            else ...[
              Text(
                _explanation ?? '',
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launcher.launchUrl(Uri.parse('https://en.wikipedia.org/wiki/${Uri.encodeComponent(widget.term)}')),
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: const Text('Wikipedia'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({super.key, required this.url, required this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => launcher.launchUrl(Uri.parse(widget.url)),
            tooltip: 'Open in External Browser',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<dynamic> _sources = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSources();
  }

  Future<void> _fetchSources() async {
    setState(() => _isLoading = true);
    try {
      final sources = await _db.getSources();
      setState(() {
        _sources = sources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSource(String id) async {
    try {
      await _db.toggleSource(id);
      _fetchSources();
    } catch (e) {}
  }

  Future<void> _deleteSelectedSources() async {
    for (var id in _selectedIds) {
      await _db.deleteSource(id);
    }
    setState(() => _selectedIds.clear());
    _fetchSources();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _showAddSourceDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add RSS Source', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'RSS URL', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty && urlController.text.isNotEmpty) {
                    await _db.addSource({
                      'name': nameController.text,
                      'url': urlController.text,
                      'type': 'rss',
                    });
                    Navigator.pop(context);
                    _fetchSources();
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('Add Source'),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelectionMode = _selectedIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode ? '${_selectedIds.length} Selected' : 'Manage Sources'),
        leading: isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedIds.clear()))
          : null,
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Selected?'),
                    content: Text('Remove ${_selectedIds.length} sources?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          _deleteSelectedSources();
                          Navigator.pop(context);
                        },
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: isSelectionMode ? null : FloatingActionButton(
        onPressed: _showAddSourceDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _sources.length,
              itemBuilder: (context, index) {
                final source = _sources[index];
                final isSelected = _selectedIds.contains(source['id']);
                
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  onLongPress: () => _toggleSelection(source['id']),
                  onTap: isSelectionMode ? () => _toggleSelection(source['id']) : null,
                  title: Text(source['name']),
                  subtitle: Text(source['url'], style: const TextStyle(fontSize: 12)),
                  leading: isSelectionMode 
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(source['id']),
                      )
                    : null,
                  trailing: isSelectionMode ? null : Switch(
                    value: source['active'] == 1,
                    onChanged: (value) => _toggleSource(source['id']),
                  ),
                );
              },
            ),
    );
  }
}

class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  State<DatabaseViewerScreen> createState() => _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends State<DatabaseViewerScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _articles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);
    final articles = await _db.getAllArticles();
    setState(() {
      _articles = articles;
      _isLoading = false;
    });
  }

  Future<void> _deleteArticle(String id) async {
    await _db.deleteArticle(id);
    _loadArticles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Viewer'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadArticles),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? const Center(child: Text('Database is empty.'))
              : ListView.separated(
                  itemCount: _articles.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final article = _articles[index];
                    return ExpansionTile(
                      title: Text(
                        article['title'] ?? 'No Title',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Article?'),
                              content: const Text('Are you sure you want to remove this article?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    _deleteArticle(article['id']);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      subtitle: Text(
                        'Source: ${article['source']} • ID: ${article['id'].toString().substring(0, 8)}...',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRawRow('ID', article['id']),
                              _buildRawRow('URL', article['url']),
                              _buildRawRow('Fetched', article['fetched_at']),
                              _buildRawRow('Crux Model', article['crux_model']),
                              _buildRawRow('Concepts', article['concepts']),
                              const SizedBox(height: 8),
                              const Text('FULL TEXT PREVIEW:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              const SizedBox(height: 4),
                              Text(
                                article['full_text']?.toString().substring(0, 500) ?? 'N/A',
                                style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildRawRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            TextSpan(text: value?.toString() ?? 'NULL', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final List<String> _providers = ['Gemini', 'Groq', 'Mistral', 'OpenRouter'];
  String _selectedProvider = 'Gemini';
  final _keyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _obscureKey = true;

  final Map<String, String> _defaultModels = {
    'Gemini': 'gemini-2.0-flash',
    'Groq': 'llama-3.3-70b-versatile',
    'Mistral': 'mistral-small-latest',
    'OpenRouter': '',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedProvider = prefs.getString('apiProvider') ?? 'Gemini';
      _keyController.text = prefs.getString('apiKey') ?? '';
      _modelController.text = prefs.getString('apiModel') ?? _defaultModels[_selectedProvider]!;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiProvider', _selectedProvider);
    await prefs.setString('apiKey', _keyController.text);
    await prefs.setString('apiModel', _modelController.text);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved locally')),
      );
    }
  }

  void _onProviderChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedProvider = value;
        _modelController.text = _defaultModels[value]!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Provider',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: _onProviderChanged,
            ),
            const SizedBox(height: 24),
            const Text(
              'API Key',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Enter your API key',
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Model Name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. gemini-2.0-flash',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, size: 20, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your API key is stored locally on this device and is only used to communicate with the selected AI provider.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PromptSettingsScreen extends StatefulWidget {
  const PromptSettingsScreen({super.key});

  @override
  State<PromptSettingsScreen> createState() => _PromptSettingsScreenState();
}

class _PromptSettingsScreenState extends State<PromptSettingsScreen> {
  final _cruxController = TextEditingController();
  final _explanationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrompts();
  }

  Future<void> _loadPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cruxController.text = prefs.getString('cruxPrompt') ?? DefaultPrompts.crux;
      _explanationController.text = prefs.getString('explanationPrompt') ?? DefaultPrompts.explanation;
    });
  }

  Future<void> _savePrompts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cruxPrompt', _cruxController.text);
    await prefs.setString('explanationPrompt', _explanationController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prompts updated successfully.')));
    }
  }

  void _resetToDefault() {
    setState(() {
      _cruxController.text = DefaultPrompts.crux;
      _explanationController.text = DefaultPrompts.explanation;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_rounded),
            onPressed: _resetToDefault,
            tooltip: 'Reset to Defaults',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Crux & Concept Extraction',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Used when a new article is ingested. Must return JSON.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cruxController,
              maxLines: 10,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Concept Explanation',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Used when you tap a highlighted concept. Contextualizes the term.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _explanationController,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savePrompts,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Save Prompts'),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
