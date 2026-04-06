import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../data/recommended_sources.dart';

/// Screen for managing RSS/news sources — add, toggle active, delete.
///
/// Long-press enters multi-select mode for batch deletion.
/// Includes a "Recommended Sources" bottom sheet for one-tap adds.
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

  // Track which recommended sources are already added
  Set<String> _addedUrls = {};

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
        _addedUrls = sources.map<String>((s) => s['url'].toString()).toSet();
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
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Custom Source',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'RSS / HTML URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty &&
                      urlController.text.isNotEmpty) {
                    await _db.addSource({
                      'name': nameController.text,
                      'url': urlController.text,
                      'type': urlController.text.contains('.xml') ||
                              urlController.text.contains('/feed') ||
                              urlController.text.contains('/rss')
                          ? 'rss'
                          : 'html',
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      _fetchSources();
                    }
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

  /// Shows a bottom sheet with recommended sources grouped by category.
  void _showRecommendedSources() {
    // Group by category
    final categories = <String, List<RecommendedSource>>{};
    for (final source in recommendedSources) {
      categories.putIfAbsent(source.category, () => []).add(source);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Recommended Sources',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${_addedUrls.length} added',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: categories.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                      ...entry.value.map((source) {
                        final isAdded = _addedUrls.contains(source.url);
                        return _RecommendedSourceTile(
                          source: source,
                          isAdded: isAdded,
                          onTap: () async {
                            await _db.addSource({
                              'name': source.name,
                              'url': source.url,
                              'type': source.type,
                            });
                            await _fetchSources();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "${source.name}"'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
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
        title: Text(isSelectionMode
            ? '${_selectedIds.length} Selected'
            : 'Manage Sources'),
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedIds.clear()),
              )
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
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          _deleteSelectedSources();
                          Navigator.pop(context);
                        },
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'addCustom',
                  onPressed: _showAddSourceDialog,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'addRecommended',
                  onPressed: _showRecommendedSources,
                  label: const Text('Recommended'),
                  icon: const Icon(Icons.star_rounded),
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sources.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rss_feed_rounded,
                          size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      const Text('No sources added yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showRecommendedSources,
                        icon: const Icon(Icons.star_rounded),
                        label: const Text('Browse recommended sources'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _sources.length,
                  itemBuilder: (context, index) {
                    final source = _sources[index];
                    final isSelected = _selectedIds.contains(source['id']);

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.3),
                      onLongPress: () => _toggleSelection(source['id']),
                      onTap: isSelectionMode
                          ? () => _toggleSelection(source['id'])
                          : null,
                      title: Text(source['name']),
                      subtitle: Text(source['url'],
                          style: const TextStyle(fontSize: 12)),
                      leading: isSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(source['id']),
                            )
                          : const Icon(Icons.rss_feed_rounded, size: 22),
                      trailing: isSelectionMode
                          ? null
                          : Switch(
                              value: source['active'] == 1,
                              onChanged: (value) =>
                                  _toggleSource(source['id']),
                            ),
                    );
                  },
                ),
    );
  }
}

/// A single recommended source tile — shows name, description, and add/check icon.
class _RecommendedSourceTile extends StatelessWidget {
  final RecommendedSource source;
  final bool isAdded;
  final VoidCallback onTap;

  const _RecommendedSourceTile({
    required this.source,
    required this.isAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        source.type == 'rss' ? Icons.rss_feed_rounded : Icons.language_rounded,
        size: 22,
        color: isAdded
            ? Theme.of(context).colorScheme.primary
            : Colors.grey[500],
      ),
      title: Text(
        source.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isAdded ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Text(source.description,
          style: const TextStyle(fontSize: 12)),
      trailing: isAdded
          ? const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 24)
          : IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
              onPressed: onTap,
            ),
    );
  }
}
