import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Settings screen for configuring the AI provider, API key, and model name.
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
  bool _isTesting = false;

  /// Default model names per provider for convenience.
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
      _modelController.text =
          prefs.getString('apiModel') ?? _defaultModels[_selectedProvider]!;
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

  Future<void> _testConnection() async {
    if (_keyController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an API key first.')),
      );
      return;
    }

    setState(() => _isTesting = true);

    final model = _modelController.text;
    final key = _keyController.text;

    try {
      String? error;

      if (_selectedProvider == 'Gemini') {
        final url =
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {'parts': [{'text': 'Reply with OK'}]}
            ],
          }),
        );
        if (response.statusCode != 200) {
          error =
              'HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}';
        }
      } else {
        final Map<String, String> baseUrls = {
          'Groq': 'https://api.groq.com/openai/v1',
          'Mistral': 'https://api.mistral.ai/v1',
          'OpenRouter': 'https://openrouter.ai/api/v1',
        };
        final baseUrl = baseUrls[_selectedProvider];
        final response = await http.post(
          Uri.parse('$baseUrl/chat/completions'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [{'role': 'user', 'content': 'Reply with OK'}],
            'max_tokens': 10,
          }),
        );
        if (response.statusCode != 200) {
          error =
              'HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}';
        }
      }

      if (!mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection successful! ✓'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
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
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _providers
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: _onProviderChanged,
            ),
            const SizedBox(height: 24),
            const Text(
              'API Key',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
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
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.wifi_find_rounded, size: 20),
                    label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
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
