import 'package:flutter/material.dart';
import '../services/database_helper.dart';

/// Debug screen that displays all stored articles with expandable details.
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

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all articles and reset sources to defaults. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.clearAllData();
      _loadArticles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Viewer'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadArticles),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: _clearAllData,
            tooltip: 'Clear All Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? const Center(child: Text('Database is empty.'))
              : ListView.separated(
                  itemCount: _articles.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final article = _articles[index];
                    return ExpansionTile(
                      title: Text(
                        article['title'] ?? 'No Title',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: Colors.redAccent),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Article?'),
                              content: const Text(
                                  'Are you sure you want to remove this article?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    _deleteArticle(article['id']);
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
                      subtitle: Text(
                        'Source: ${article['source']} • ID: ${article['id'].toString().substring(0, 8)}...',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
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
                              const Text(
                                'FULL TEXT PREVIEW:',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                article['full_text']
                                        ?.toString()
                                        .substring(0, 500) ??
                                    'N/A',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontFamily: 'monospace'),
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
          style:
              const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            TextSpan(
                text: value?.toString() ?? 'NULL',
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
