/// A curated list of major news sources with working RSS feed URLs.
///
/// Each source includes a name, RSS/HTML URL, type, category, and a
/// short description shown in the recommendation sheet.
class RecommendedSource {
  final String name;
  final String url;
  final String type; // 'rss' or 'html'
  final String category;
  final String description;

  const RecommendedSource({
    required this.name,
    required this.url,
    required this.type,
    required this.category,
    required this.description,
  });
}

/// All recommended sources, grouped by region/category.
const List<RecommendedSource> recommendedSources = [
  // ── India ────────────────────────────────────────────────────────
  RecommendedSource(
    name: 'The Hindu',
    url: 'https://www.thehindu.com/news/national/feeder/default.rss',
    type: 'rss',
    category: 'India',
    description: 'Editorials & national news',
  ),
  RecommendedSource(
    name: 'The Hindu — Business',
    url: 'https://www.thehindu.com/business/feeder/default.rss',
    type: 'rss',
    category: 'India',
    description: 'Business & economy coverage',
  ),
  RecommendedSource(
    name: 'Indian Express',
    url: 'https://indianexpress.com/section/india/feed/',
    type: 'rss',
    category: 'India',
    description: 'India section RSS feed',
  ),
  RecommendedSource(
    name: 'Scroll.in',
    url: 'https://scroll.in',
    type: 'html',
    category: 'India',
    description: 'Independent journalism — HTML scraping',
  ),
  RecommendedSource(
    name: 'The Hindu — Opinion',
    url: 'https://www.thehindu.com/opinion/editorial/feeder/default.rss',
    type: 'rss',
    category: 'India',
    description: 'Editorial opinion pieces',
  ),
  RecommendedSource(
    name: 'NDTV — Top Stories',
    url: 'http://feeds.ndtv.com/ndtv/top-stories',
    type: 'rss',
    category: 'India',
    description: 'Top stories from NDTV',
  ),
  RecommendedSource(
    name: 'The Wire',
    url: 'https://thewire.in/feed',
    type: 'rss',
    category: 'India',
    description: 'Independent news and analysis',
  ),

  // ── International ────────────────────────────────────────────────
  RecommendedSource(
    name: 'The Guardian — World',
    url: 'https://www.theguardian.com/world/rss',
    type: 'rss',
    category: 'International',
    description: 'Global news from The Guardian',
  ),
  RecommendedSource(
    name: 'BBC News',
    url: 'https://feeds.bbci.co.uk/news/world/rss.xml',
    type: 'rss',
    category: 'International',
    description: 'World news from the BBC',
  ),
  RecommendedSource(
    name: 'Reuters — World',
    url: 'https://www.rss.foxnews.com/rss/world',
    type: 'rss',
    category: 'International',
    description: 'World news RSS feed',
  ),
  RecommendedSource(
    name: 'Al Jazeera',
    url: 'https://www.aljazeera.com/xml/rss/all.xml',
    type: 'rss',
    category: 'International',
    description: 'All news from Al Jazeera',
  ),
  RecommendedSource(
    name: 'The New York Times',
    url: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml',
    type: 'rss',
    category: 'International',
    description: 'NYT world news feed',
  ),

  // ── Technology ───────────────────────────────────────────────────
  RecommendedSource(
    name: 'TechCrunch',
    url: 'https://techcrunch.com/feed/',
    type: 'rss',
    category: 'Technology',
    description: 'Startup & tech industry news',
  ),
  RecommendedSource(
    name: 'Ars Technica',
    url: 'https://feeds.arstechnica.com/arstechnica/index',
    type: 'rss',
    category: 'Technology',
    description: 'Tech news and analysis',
  ),
  RecommendedSource(
    name: 'The Verge',
    url: 'https://www.theverge.com/rss/index.xml',
    type: 'rss',
    category: 'Technology',
    description: 'Tech, science, and culture',
  ),
  RecommendedSource(
    name: 'Hacker News (Best Of)',
    url: 'https://hnrss.org/best?count=25',
    type: 'rss',
    category: 'Technology',
    description: 'Top stories from Hacker News',
  ),

  // ── Science ──────────────────────────────────────────────────────
  RecommendedSource(
    name: 'Nature — News',
    url: 'https://www.nature.com/nature.rss',
    type: 'rss',
    category: 'Science',
    description: 'Latest science news from Nature',
  ),
  RecommendedSource(
    name: 'Science Daily',
    url: 'https://www.sciencedaily.com/rss/all.xml',
    type: 'rss',
    category: 'Science',
    description: 'Breaking science news from all fields',
  ),
  RecommendedSource(
    name: 'Quanta Magazine',
    url: 'https://api.quantamagazine.org/feed/',
    type: 'rss',
    category: 'Science',
    description: 'Mathematics, physics, and computer science',
  ),

  // ── Business & Finance ───────────────────────────────────────────
  RecommendedSource(
    name: 'Economist',
    url: 'https://www.economist.com/latest/rss.xml',
    type: 'rss',
    category: 'Business',
    description: 'Latest stories from The Economist',
  ),
  RecommendedSource(
    name: 'Bloomberg',
    url: 'https://feeds.bloomberg.com/markets/news.rss',
    type: 'rss',
    category: 'Business',
    description: 'Bloomberg markets news',
  ),
  RecommendedSource(
    name: 'Financial Times',
    url: 'https://www.ft.com/?format=rss',
    type: 'rss',
    category: 'Business',
    description: 'Financial Times homepage feed',
  ),
];
