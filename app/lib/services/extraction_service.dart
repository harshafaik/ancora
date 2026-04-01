import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trafilatura/trafilatura.dart' as trafilatura;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ExtractionService {
  Future<Map<String, String>?> extractContent(String url) async {
    try {
      // --- 1. First Attempt: Plain HTTP Fetch + Trafilatura ---
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
      );

      if (response.statusCode != 200) return null;

      String initialHtml = response.body;
      Map<String, String>? result = await compute(_processHtmlInIsolate, {'html': initialHtml, 'url': url});

      // --- 2. Check if Fallback is needed (text < 500 chars) ---
      if (result == null || (result['text']?.length ?? 0) < 500) {
        print("Initial extraction poor (${result?['text']?.length ?? 0} chars). Attempting WebView fallback for $url...");
        final webViewResult = await _extractWithWebView(url);
        if (webViewResult != null && (webViewResult['text']?.length ?? 0) > (result?['text']?.length ?? 0)) {
          result = webViewResult;
        }
      }

      // --- 3. Finalize Status ---
      if (result != null) {
        final textLength = result['text']?.length ?? 0;
        if (textLength < 200) {
          result['status'] = 'failed';
        } else if (textLength < 500) {
          result['status'] = 'partial';
        } else {
          result['status'] = 'ok';
        }
      }

      return result;
    } catch (e) {
      print("Extraction error for $url: $e");
      return null;
    }
  }

  Future<Map<String, String>?> _extractWithWebView(String url) async {
    Completer<Map<String, String>?> completer = Completer();
    HeadlessInAppWebView? headlessWebView;

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      onLoadStop: (controller, url) async {
        try {
          // Wait a bit for JS to settle
          await Future.delayed(const Duration(seconds: 2));
          
          // Inject JS to get the rendered body
          final String? renderedHtml = await controller.evaluateJavascript(source: "document.documentElement.outerHTML");
          
          if (renderedHtml != null && renderedHtml.isNotEmpty) {
            // Process rendered HTML in isolate
            final result = await compute(_processHtmlInIsolate, {'html': renderedHtml, 'url': url.toString()});
            completer.complete(result);
          } else {
            completer.complete(null);
          }
        } catch (e) {
          print("WebView JS error: $e");
          completer.complete(null);
        } finally {
          headlessWebView?.dispose();
        }
      },
      onReceivedError: (controller, request, error) {
        print("WebView Load Error: ${error.description}");
        completer.complete(null);
        headlessWebView?.dispose();
      },
    );

    await headlessWebView.run();
    
    return completer.future.timeout(const Duration(seconds: 20), onTimeout: () {
      print("WebView extraction timed out for $url");
      headlessWebView?.dispose();
      return null;
    });
  }
}

// --- Top-level functions for Isolate processing ---

Future<Map<String, String>?> _processHtmlInIsolate(Map<String, String> data) async {
  final String html = data['html']!;
  final String url = data['url']!;
  
  final document = html_parser.parse(html);
  _removeJunkElements(document);

  final trafilaturaText = await trafilatura.extract(
    filecontent: document.outerHtml,
    outputFormat: 'markdown',
    includeFormatting: true,
    favorPrecision: true,
    includeComments: false,
    includeTables: false,
  );

  String? contentText;
  if (url.contains('indianexpress.com')) {
    contentText = _extractIndianExpress(document);
  }

  String rawText = trafilaturaText ?? contentText ?? '';
  if (rawText.isEmpty) return null;

  List<String> paragraphs = rawText.split('\n');
  List<String> cleanedParagraphs = _deduplicateAndFilter(paragraphs);
  String finalContent = cleanedParagraphs.join('\n\n');

  // Title extraction
  String title = '';
  final metaTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'];
  final h1 = document.querySelector('h1')?.text.trim();
  final tagTitle = document.querySelector('title')?.text.trim();
  title = metaTitle ?? h1 ?? tagTitle ?? '';

  return {
    'text': finalContent,
    'title': title,
    'date': '',
    'status': 'ok',
  };
}

String? _extractIndianExpress(dom.Document doc) {
  final storyElement = doc.querySelector('.story-details') ?? doc.querySelector('#story-details') ?? doc.querySelector('.full-details');
  if (storyElement == null) return null;
  storyElement.querySelectorAll('.also-read, .related-articles, .ie-recommends, .app-exclusive, aside, .newsletter-box').forEach((el) => el.remove());
  return storyElement.text;
}

void _removeJunkElements(dom.Document doc) {
  final junkSelectors = [
    '.app-exclusive', '.ie-recommends', '.related-articles', 
    '.newsletter-box', '.social-share', '.tags', '.author-bio',
    'aside', 'script', 'style', '.ad-unit', '.inline-ad',
    '.read-also', '.also-read', '.trending-stories',
    '.video-container', '.embed-container', '.custom-ad',
    '.premium-content-paywall', '#ev-paywall'
  ];
  for (var selector in junkSelectors) {
    doc.querySelectorAll(selector).forEach((el) => el.remove());
  }
}

List<String> _deduplicateAndFilter(List<String> paragraphs) {
  Set<String> seenNormal = {};
  List<String> unique = [];
  for (var p in paragraphs) {
    String trimmed = p.trim();
    if (trimmed.isEmpty) continue;
    String normalized = trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (_isBoilerplate(trimmed.toLowerCase())) continue;
    if (normalized.length < 15 && !trimmed.startsWith('#')) continue;
    bool isDuplicate = false;
    for (var existing in seenNormal) {
      if (existing.contains(normalized) || normalized.contains(existing)) {
        isDuplicate = true;
        break;
      }
    }
    if (!isDuplicate) {
      unique.add(trimmed);
      seenNormal.add(normalized);
    }
  }
  return unique;
}

bool _isBoilerplate(String text) {
  final junkPhrases = [
    'see all', 'remove', 'advertisement', 'newsletter', 'must read',
    'click here', 'follow us on', 'subscribe to', 'read more', 
    'also read', 'related stories', 'trending now', 'join our telegram',
    'copyright', 'all rights reserved', 'written by', 'edited by',
    'explained desk', 'express news service'
  ];
  for (var phrase in junkPhrases) {
    if (text.contains(phrase)) return true;
  }
  if (RegExp(r'\d+ min read').hasMatch(text)) return true;
  return false;
}
