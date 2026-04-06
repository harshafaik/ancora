import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../services/news_service.dart';
import '../screens/article_detail_screen.dart';
import '../screens/sources_screen.dart';
import '../screens/api_settings_screen.dart';
import '../screens/prompt_settings_screen.dart';
import '../screens/database_viewer_screen.dart';

/// Calculates reading time in minutes at ~200 wpm.
int _readingTime(String? text) {
  if (text == null || text.isEmpty) return 0;
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  return (words / 200).ceil();
}

/// The main feed screen — lists articles, filters by source,
/// and provides navigation to all settings screens via the drawer.
class FeedScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final ThemeMode currentThemeMode;
  final double fontSize;
  final String fontFamily;
  final Function(double) onFontSizeChanged;
  final Function(String) onFontFamilyChanged;

  const FeedScreen({
    super.key,
    required this.onThemeToggle,
    required this.currentThemeMode,
    required this.fontSize,
    required this.fontFamily,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
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

  // Search state
  String _searchQuery = '';
  bool _isSearchActive = false;

  // View mode: 'feed' or 'bookmarks'
  String _viewMode = 'feed';

  @override
  void initState() {
    super.initState();
    _loadFromDb();
    _runBackgroundIngestion();
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
        _allArticles =
            articles.where((a) => activeSourceNames.contains(a['source'])).toList();
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
    List<dynamic> base;

    // Source filter
    if (_selectedSource == 'All') {
      base = _allArticles;
    } else {
      base = _allArticles.where((a) => a['source'] == _selectedSource).toList();
    }

    // View mode filter
    if (_viewMode == 'bookmarks') {
      base = base.where((a) => (a['is_bookmarked'] ?? 0) == 1).toList();
    }

    // Search filter
    if (_isSearchActive && _searchQuery.isNotEmpty) {
      base = base.where((a) {
        final title = (a['title'] ?? '').toString().toLowerCase();
        final crux = (a['crux'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return title.contains(query) || crux.contains(query);
      }).toList();
    }

    setState(() => _filteredArticles = base);
  }

  Future<void> _toggleBookmark(Map<String, dynamic> article) async {
    await _db.toggleBookmark(article['url']);
    _loadFromDb(); // Reload to update UI
  }

  Future<void> _openArticle(Map<String, dynamic> article) async {
    // Mark as read
    await _db.markAsRead(article['url']);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          fontSize: widget.fontSize,
          fontFamily: widget.fontFamily,
          onFontSizeChanged: widget.onFontSizeChanged,
          onFontFamilyChanged: widget.onFontFamilyChanged,
        ),
      ),
    );

    // Refresh read status when returning
    _loadFromDb();
  }

  // ── Build methods ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchActive
            ? TextField(
                autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search articles…',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _applyFilter();
                },
              )
            : Text(
                _viewMode == 'bookmarks' ? 'Bookmarks' : 'Ancora',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
        elevation: 0,
        leading: _isSearchActive
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _isSearchActive = false;
                    _searchQuery = '';
                  });
                  _applyFilter();
                },
              )
            : null,
        actions: [
          if (!_isSearchActive)
            IconButton(
              icon: Icon(
                _viewMode == 'bookmarks'
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color:
                    _viewMode == 'bookmarks'
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == 'bookmarks' ? 'feed' : 'bookmarks';
                });
                _applyFilter();
              },
              tooltip:
                  _viewMode == 'bookmarks' ? 'Show all' : 'Show bookmarks',
            ),
          if (!_isSearchActive)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _isSearchActive = true),
              tooltip: 'Search',
            ),
          IconButton(
            icon: Icon(widget.currentThemeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.dark_mode),
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
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark ? Colors.black : null,
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
                  Text('Ancora',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_input_component_outlined),
            title: const Text('Manage Sources'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SourcesScreen()),
              );
              _loadFromDb();
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border_rounded),
            title: const Text('Bookmarks'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _viewMode = 'bookmarks');
              _applyFilter();
            },
          ),
          ListTile(
            leading: const Icon(Icons.api_rounded),
            title: const Text('API Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ApiSettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.terminal_rounded),
            title: const Text('Prompt Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PromptSettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage_rounded),
            title: const Text('Database Viewer'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const DatabaseViewerScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Clear Read History'),
            onTap: () {
              Navigator.pop(context);
              _db.clearReadHistory();
              _loadFromDb();
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'Ancora',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.newspaper, size: 48),
                children: [
                  const Text(
                      'Ancora is a minimal news reader that uses AI to extract the "Crux" of every article, saving you time.'),
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
              ElevatedButton(
                  onPressed: _fetchData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_filteredArticles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _viewMode == 'bookmarks'
                  ? Icons.bookmark_border_rounded
                  : Icons.search_off_rounded,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              _viewMode == 'bookmarks'
                  ? 'No bookmarks yet'
                  : _isSearchActive
                      ? 'No results for "$_searchQuery"'
                      : 'No articles found.',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Show result count when searching
    final Widget? searchHeader =
        (_isSearchActive && _searchQuery.isNotEmpty)
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '${_filteredArticles.length} result${_filteredArticles.length == 1 ? '' : 's'} for "$_searchQuery"',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null;

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: CustomScrollView(
        slivers: [
          if (searchHeader != null)
            SliverToBoxAdapter(child: searchHeader),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final article = _filteredArticles[index];
                final isRead = (article['is_read'] ?? 0) == 1;
                final isBookmarked = (article['is_bookmarked'] ?? 0) == 1;
                final minutes = _readingTime(article['full_text']);

                return GestureDetector(
                  onTap: () => _openArticle(article),
                  child: Opacity(
                    opacity: isRead ? 0.55 : 1.0,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    article['source'] ?? 'Unknown Source',
                                    style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                // Bookmark toggle
                                IconButton(
                                  icon: Icon(
                                    isBookmarked
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    size: 20,
                                    color: isBookmarked
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[600],
                                  ),
                                  onPressed: () => _toggleBookmark(article),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    article['title'] ?? 'No Title',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (isRead)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[700],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Read',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white70),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (minutes > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '$minutes min read',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (article['crux'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                article['crux'],
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[300],
                                    height: 1.5,
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: _filteredArticles.length,
            ),
          ),
        ],
      ),
    );
  }
}
