import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/default_prompts.dart';

/// Settings screen for customising the AI prompts used for crux extraction
/// and concept explanation.
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
      _cruxController.text =
          prefs.getString('cruxPrompt') ?? DefaultPrompts.crux;
      _explanationController.text =
          prefs.getString('explanationPrompt') ?? DefaultPrompts.explanation;
    });
  }

  Future<void> _savePrompts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cruxPrompt', _cruxController.text);
    await prefs.setString('explanationPrompt', _explanationController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prompts updated successfully.')),
      );
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
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
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
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
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
