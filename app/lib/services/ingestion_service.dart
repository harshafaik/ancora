import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class IngestionService {
  Future<List<String>> discoverRss(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final feed = RssFeed.parse(response.body);
        return feed.items.map((item) => item.link ?? '').where((link) => link.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      // Try Atom if RSS fails
      try {
        final response = await http.get(Uri.parse(url));
        final feed = AtomFeed.parse(response.body);
        return feed.items.map((item) => item.links.first.href ?? '').where((link) => link.isNotEmpty).toList();
      } catch (_) {
        print("RSS/Atom Discovery error for $url: $e");
        return [];
      }
    }
  }

  Future<List<String>> discoverHtml(String url, {List<String>? articlePatterns, List<String>? excludePatterns}) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final List<dom.Element> links = document.querySelectorAll('a[href]');
        final Set<String> articleLinks = {};

        for (var link in links) {
          String? href = link.attributes['href'];
          if (href == null) continue;

          // Make absolute
          if (href.startsWith('/')) {
            final uri = Uri.parse(url);
            href = '${uri.scheme}://${uri.host}$href';
          }

          if (!href.startsWith('http')) continue;

          // Filtering
          bool matches = articlePatterns == null || articlePatterns.isEmpty;
          if (articlePatterns != null) {
            for (var pattern in articlePatterns) {
              if (href.contains(pattern)) {
                matches = true;
                break;
              }
            }
          }

          bool excluded = false;
          if (excludePatterns != null) {
            for (var pattern in excludePatterns) {
              if (href.contains(pattern)) {
                excluded = true;
                break;
              }
            }
          }

          if (matches && !excluded) {
            articleLinks.add(href);
          }
        }
        return articleLinks.toList();
      }
      return [];
    } catch (e) {
      print("HTML Discovery error for $url: $e");
      return [];
    }
  }
}
