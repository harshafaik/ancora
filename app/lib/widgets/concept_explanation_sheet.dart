import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import '../services/ai_service.dart';

/// Bottom sheet that explains a single concept extracted from an article.
///
/// Fetches an AI-generated explanation contextualised to the article,
/// then offers a Wikipedia link for further reading.
class ConceptExplanationSheet extends StatefulWidget {
  final String term;
  final String contextText;
  final String provider;
  final String apiKey;
  final String model;
  final String customPrompt;

  const ConceptExplanationSheet({
    super.key,
    required this.term,
    required this.contextText,
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.customPrompt,
  });

  @override
  State<ConceptExplanationSheet> createState() => _ConceptExplanationSheetState();
}

class _ConceptExplanationSheetState extends State<ConceptExplanationSheet> {
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
        _error = 'Failed to generate explanation.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Colors.blueAccent,
                        ),
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
                      onPressed: () => launcher.launchUrl(
                        Uri.parse('https://en.wikipedia.org/wiki/${Uri.encodeComponent(widget.term)}'),
                      ),
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
