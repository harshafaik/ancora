import 'package:flutter/material.dart';
import '../services/keyword_alerts.dart';

/// Settings screen for managing keyword alerts.
///
/// Articles matching any keyword get a visual tag in the feed.
class KeywordAlertsScreen extends StatefulWidget {
  const KeywordAlertsScreen({super.key});

  @override
  State<KeywordAlertsScreen> createState() => _KeywordAlertsScreenState();
}

class _KeywordAlertsScreenState extends State<KeywordAlertsScreen> {
  final List<String> _keywords = [];
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  Future<void> _loadKeywords() async {
    final keywords = await KeywordAlerts.getKeywords();
    if (mounted) setState(() {
      _keywords.clear();
      _keywords.addAll(keywords);
    });
  }

  Future<void> _addKeyword() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty || _keywords.contains(keyword)) return;

    _keywords.add(keyword);
    await KeywordAlerts.setKeywords(_keywords);
    _controller.clear();
    if (mounted) setState(() {});
  }

  Future<void> _removeKeyword(String keyword) async {
    _keywords.remove(keyword);
    await KeywordAlerts.setKeywords(_keywords);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keyword Alerts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add keywords to watch for',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Articles containing these words will be tagged in the feed',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'e.g. RBI, Supreme Court, Budget',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addKeyword(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addKeyword,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _keywords.isEmpty
                ? const Center(
                    child: Text(
                      'No keywords set yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _keywords.length,
                    separatorBuilder: (context, i) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final keyword = _keywords[i];
                      return ListTile(
                        leading: const Icon(Icons.label_outline_rounded),
                        title: Text(keyword),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _removeKeyword(keyword),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
