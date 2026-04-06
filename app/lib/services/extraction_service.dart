import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trafilatura/trafilatura.dart' as trafilatura;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Extracts readable text from a news article URL.
///
/// Pipeline:
///   1. Plain HTTP fetch + trafilatura (fast, no WebView overhead).
///   2. If the result is < 500 chars, fall back to a silent headless WebView
///      that renders JavaScript-heavy pages, then re-runs trafilatura.
///   3. Returns a map with `text`, `title`, `date`, and `extraction_status`.
///
/// Extraction status thresholds:
///   - 'ok'      : 500+ characters of body text
///   - 'partial' : 200–499 characters
///   - 'failed'  : < 200 characters
class ExtractionService {
  Future<Map<String, String>?> extractContent(String url) async {
    try {
      // ── Step 1: Plain HTTP + Trafilatura ──────────────────────────────
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/120.0.0.0 Safari/537.36',
        },
      );

      if (response.statusCode != 200) return null;

      Map<String, String>? result = await compute(
        _processHtmlInIsolate,
        {'html': response.body, 'url': url},
      );

      // ── Step 2: WebView fallback if text is too short ─────────────────
      final textLength = result?['text']?.length ?? 0;
      if (textLength < 500) {
        result = await _extractWithWebView(url);
      }

      // ── Step 3: Assign extraction_status ──────────────────────────────
      if (result != null) {
        result['extraction_status'] = _classifyStatus(textLength);
      }

      return result;
    } catch (e) {
      print('Extraction error for $url: $e');
      return null;
    }
  }

  /// Classifies the extraction result based on character count.
  String _classifyStatus(int length) {
    if (length < 200) return 'failed';
    if (length < 500) return 'partial';
    return 'ok';
  }

  // ── Silent WebView fallback ─────────────────────────────────────────────

  /// Spins up a headless (completely invisible) WebView, waits for the page
  /// to fully render (including JS), then extracts the HTML and runs it
  /// through the same trafilatura pipeline.
  Future<Map<String, String>?> _extractWithWebView(String url) async {
    print('WebView fallback for $url');

    final completer = Completer<Map<String, String>?>();
    HeadlessInAppWebView? headlessWebView;

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      onLoadStop: (controller, _) async {
        try {
          // Let dynamic content settle.
          await Future.delayed(const Duration(seconds: 2));

          // Grab the full rendered HTML from the DOM.
          final renderedHtml = await controller.evaluateJavascript(
            source: 'document.documentElement.outerHTML;',
          ) as String?;

          if (renderedHtml != null && renderedHtml.isNotEmpty) {
            final result = await compute(
              _processHtmlInIsolate,
              {'html': renderedHtml, 'url': url},
            );
            completer.complete(result);
          } else {
            // HTML extraction failed — try raw body text as last resort.
            final rawText = await _extractRawBodyText(controller);
            completer.complete(rawText);
          }
        } catch (e) {
          print('WebView JS error: $e');
          completer.complete(null);
        } finally {
          headlessWebView?.dispose();
        }
      },
      onReceivedError: (controller, request, error) {
        print('WebView Load Error: ${error.description}');
        completer.complete(null);
        headlessWebView?.dispose();
      },
    );

    await headlessWebView.run();

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        print('WebView extraction timed out for $url');
        headlessWebView?.dispose();
        return null;
      },
    );
  }

  /// Last-resort: grab document.body.innerText directly via JavaScript.
  /// The raw text is cleaned and passed through the same deduplication logic
  /// (but NOT trafilatura, since we already have plain text).
  Future<Map<String, String>?> _extractRawBodyText(
    InAppWebViewController controller,
  ) async {
    final rawText = await controller.evaluateJavascript(
      source: 'document.body?.innerText ?? "";',
    ) as String?;

    if (rawText == null || rawText.trim().isEmpty) return null;

    final lines = rawText.split('\n');
    final cleaned = _deduplicateAndFilter(lines);
    final text = cleaned.join('\n\n');

    return {
      'text': text,
      'title': '',
      'date': '',
      'extraction_status': _classifyStatus(text.length),
    };
  }
}

// ─── Isolate-safe processing functions ─────────────────────────────────────

Future<Map<String, String>?> _processHtmlInIsolate(
  Map<String, String> data,
) async {
  final String html = data['html']!;
  final String url = data['url']!;

  final document = html_parser.parse(html);
  _removeJunkElements(document);

  // Primary: trafilatura extraction (plain text output).
  final trafilaturaText = await trafilatura.extract(
    filecontent: document.outerHtml,
    outputFormat: 'txt',
    includeFormatting: false,
    favorPrecision: true,
    includeComments: false,
    includeTables: false,
  );

  // Source-specific fallback.
  String? contentText;
  if (url.contains('indianexpress.com')) {
    contentText = _extractIndianExpress(document);
  }

  String rawText = trafilaturaText ?? contentText ?? '';
  if (rawText.isEmpty) return null;

  // Clean and deduplicate.
  final paragraphs = rawText.split('\n');
  final cleanedParagraphs = _deduplicateAndFilter(paragraphs);
  final finalContent = cleanedParagraphs.join('\n\n');

  // Title extraction.
  final metaTitle =
      document.querySelector('meta[property="og:title"]')?.attributes['content'];
  final h1 = document.querySelector('h1')?.text.trim();
  final tagTitle = document.querySelector('title')?.text.trim();
  final title = metaTitle ?? h1 ?? tagTitle ?? '';

  return {
    'text': finalContent,
    'title': title,
    'date': '',
  };
}

/// Source-specific extractor for Indian Express articles.
String? _extractIndianExpress(dom.Document doc) {
  final storyElement =
      doc.querySelector('.story-details') ??
      doc.querySelector('#story-details') ??
      doc.querySelector('.full-details');

  if (storyElement == null) return null;

  storyElement
      .querySelectorAll(
        '.also-read, .related-articles, .ie-recommends, '
        '.app-exclusive, aside, .newsletter-box',
      )
      .forEach((el) => el.remove());

  return storyElement.text;
}

/// Strips ads, share buttons, paywalls, and other junk from the DOM before
/// passing to trafilatura.
void _removeJunkElements(dom.Document doc) {
  final junkSelectors = [
    '.app-exclusive',
    '.ie-recommends',
    '.related-articles',
    '.newsletter-box',
    '.social-share',
    '.tags',
    '.author-bio',
    'aside',
    'script',
    'style',
    '.ad-unit',
    '.inline-ad',
    '.read-also',
    '.also-read',
    '.trending-stories',
    '.video-container',
    '.embed-container',
    '.custom-ad',
    '.premium-content-paywall',
    '#ev-paywall',
  ];

  for (final selector in junkSelectors) {
    doc.querySelectorAll(selector).forEach((el) => el.remove());
  }
}

/// Removes empty lines, boilerplate phrases, and exact duplicates.
/// Less aggressive than before — containment matching is removed so
/// short valid sentences are not absorbed by longer paragraphs.
List<String> _deduplicateAndFilter(List<String> paragraphs) {
  final seenExact = <String>{};
  final unique = <String>[];

  for (final p in paragraphs) {
    final trimmed = p.trim();
    if (trimmed.isEmpty) continue;

    final normalized =
        trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (_isBoilerplate(trimmed.toLowerCase())) continue;
    if (normalized.length < 10 && !trimmed.startsWith('#')) continue;

    // Only skip exact duplicates
    if (!seenExact.contains(normalized)) {
      unique.add(trimmed);
      seenExact.add(normalized);
    }
  }

  return unique;
}

/// Detects common boilerplate phrases that shouldn't appear in article text.
bool _isBoilerplate(String text) {
  final junkPhrases = [
    'see all',
    'remove',
    'advertisement',
    'newsletter',
    'must read',
    'click here',
    'follow us on',
    'subscribe to',
    'read more',
    'also read',
    'related stories',
    'trending now',
    'join our telegram',
    'copyright',
    'all rights reserved',
    'written by',
    'edited by',
    'explained desk',
    'express news service',
  ];

  for (final phrase in junkPhrases) {
    if (text.contains(phrase)) return true;
  }

  if (RegExp(r'\d+ min read').hasMatch(text)) return true;
  return false;
}
