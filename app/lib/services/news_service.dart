import 'dart:convert';
import 'database_helper.dart';
import 'ingestion_service.dart';
import 'extraction_service.dart';
import 'ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsService {
  final DatabaseHelper _db = DatabaseHelper();
  final IngestionService _ingestion = IngestionService();
  final ExtractionService _extraction = ExtractionService();
  final AiService _ai = AiService();

  Future<Map<String, int>> runIngestion() async {
    int newArticlesCount = 0;
    int newCruxesCount = 0;

    // 1. Get active sources
    final activeSources = await _db.getActiveSources();
    
    // 2. Discover and Extract from sources in parallel
    final sourceFutures = activeSources.map((source) async {
      List<String> links = [];
      if (source['type'] == 'rss') {
        links = await _ingestion.discoverRss(source['url']);
      } else if (source['type'] == 'html') {
        links = await _ingestion.discoverHtml(source['url']);
      }

      // Process links in this source
      // Limit to 5 per source for now
      final linkFutures = links.take(5).map((link) async {
        final extracted = await _extraction.extractContent(link);
        
        if (extracted != null && extracted['text'] != null) {
          final isNew = await _db.upsertArticle({
            'source': source['name'],
            'url': link,
            'title': extracted['title'],
            'published_at': extracted['date'],
            'full_text': extracted['text'],
            'extraction_status': extracted['extraction_status'] ?? 'ok',
          });
          return isNew;
        }
        return false;
      });

      final results = await Future.wait(linkFutures);
      return results.where((isNew) => isNew).length;
    });

    final counts = await Future.wait(sourceFutures);
    newArticlesCount = counts.fold(0, (sum, count) => sum + count);

    // 3. Process cruxes for unprocessed articles
    final unprocessed = await _db.getUnprocessedArticles();
    if (unprocessed.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final provider = prefs.getString('apiProvider') ?? 'Gemini';
      final apiKey = prefs.getString('apiKey') ?? '';
      final model = prefs.getString('apiModel') ?? (provider == 'Gemini' ? 'gemini-2.0-flash' : '');
      final customCruxPrompt = prefs.getString('cruxPrompt');

      if (apiKey.isNotEmpty) {
        final cruxFutures = unprocessed.map((article) async {
          final result = await _ai.getCruxAndConcepts(
            text: article['full_text'],
            provider: provider,
            apiKey: apiKey,
            model: model,
            promptTemplate: customCruxPrompt,
          );

          if (result.containsKey('crux')) {
            final crux = result['crux'];
            final concepts = jsonEncode(result['concepts'] ?? []);
            await _db.updateCrux(
              article['url'],
              crux,
              model.isNotEmpty ? model : provider,
              concepts: concepts,
            );
            return true;
          }

          // Log the error so it's visible in console
          final error = result['error'] ?? 'Unknown error';
          print('[CruxGen] Failed for ${article['title']}: $error');
          return false;
        });

        final results = await Future.wait(cruxFutures);
        newCruxesCount = results.where((success) => success).length;

        final failed = results.where((s) => !s).length;
        if (failed > 0) {
          print('[CruxGen] $failed crux(es) failed to generate. Check API key and model.');
        }
      }
    }

    return {
      'new_articles': newArticlesCount,
      'new_cruxes': newCruxesCount,
    };
  }
}
