import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // On desktop, use FFI factory. On Android/iOS, use native sqflite.
    // Never overwrite the global databaseFactory — it pollutes all platforms.
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      final dbDir = join(
        Platform.environment['HOME'] ?? '.',
        '.local', 'share', 'ancora',
      );
      await Directory(dbDir).create(recursive: true);
      final path = join(dbDir, 'ancora.db');
      return await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    // Android/iOS: native sqflite
    final path = join(await getDatabasesPath(), 'ancora.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE articles ADD COLUMN extraction_status TEXT DEFAULT "ok"');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE articles ADD COLUMN concepts TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE articles ADD COLUMN is_bookmarked INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE articles ADD COLUMN is_read INTEGER DEFAULT 0');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        url TEXT NOT NULL,
        added_at TEXT NOT NULL,
        active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE articles (
        id TEXT PRIMARY KEY,
        source TEXT NOT NULL,
        url TEXT UNIQUE NOT NULL,
        title TEXT,
        published_at TEXT,
        fetched_at TEXT NOT NULL,
        full_text TEXT,
        crux TEXT,
        crux_model TEXT,
        extraction_status TEXT DEFAULT "ok",
        concepts TEXT,
        is_bookmarked INTEGER DEFAULT 0,
        is_read INTEGER DEFAULT 0
      )
    ''');

    // Seed default sources
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('sources', {
      'id': generateId('https://www.thehindu.com/opinion/editorial/feeder/default.rss'),
      'name': 'The Hindu Editorial',
      'type': 'rss',
      'url': 'https://www.thehindu.com/opinion/editorial/feeder/default.rss',
      'added_at': now,
      'active': 1
    });
    await db.insert('sources', {
      'id': generateId('https://www.thehindu.com/news/national/feeder/default.rss'),
      'name': 'The Hindu National',
      'type': 'rss',
      'url': 'https://www.thehindu.com/news/national/feeder/default.rss',
      'added_at': now,
      'active': 1
    });
    await db.insert('sources', {
      'id': generateId('https://scroll.in'),
      'name': 'Scroll',
      'type': 'html',
      'url': 'https://scroll.in',
      'added_at': now,
      'active': 1
    });
  }

  String generateId(String url) {
    return sha256.convert(utf8.encode(url)).toString();
  }

  // Sources CRUD
  Future<List<Map<String, dynamic>>> getSources() async {
    Database db = await database;
    return await db.query('sources', orderBy: 'added_at DESC');
  }

  Future<List<Map<String, dynamic>>> getActiveSources() async {
    Database db = await database;
    return await db.query('sources', where: 'active = 1');
  }

  Future<String> addSource(Map<String, dynamic> source) async {
    Database db = await database;
    String id = generateId(source['url']);
    Map<String, dynamic> sourceWithId = Map.from(source);
    sourceWithId['id'] = id;
    sourceWithId['added_at'] = DateTime.now().toUtc().toIso8601String();
    sourceWithId['active'] = 1;
    await db.insert('sources', sourceWithId, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> toggleSource(String id) async {
    Database db = await database;
    await db.rawUpdate('UPDATE sources SET active = 1 - active WHERE id = ?', [id]);
  }

  Future<void> deleteSource(String id) async {
    Database db = await database;
    // Get the source name before deleting to clean up articles
    List<Map<String, dynamic>> source = await db.query('sources', where: 'id = ?', whereArgs: [id]);
    if (source.isNotEmpty) {
      String sourceName = source.first['name'];
      // Delete all articles from this source
      await db.delete('articles', where: 'source = ?', whereArgs: [sourceName]);
    }
    await db.delete('sources', where: 'id = ?', whereArgs: [id]);
  }

  // Articles CRUD
  Future<List<Map<String, dynamic>>> getAllArticles() async {
    Database db = await database;
    return await db.query('articles', orderBy: 'fetched_at DESC');
  }

  Future<Map<String, dynamic>?> getArticleById(String id) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query('articles', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getUnprocessedArticles() async {
    Database db = await database;
    return await db.query('articles', where: 'crux IS NULL');
  }

  Future<bool> upsertArticle(Map<String, dynamic> article) async {
    Database db = await database;
    String id = generateId(article['url']);
    Map<String, dynamic> articleWithId = Map.from(article);
    articleWithId['id'] = id;
    articleWithId['fetched_at'] ??= DateTime.now().toUtc().toIso8601String();
    
    int count = await db.insert('articles', articleWithId, conflictAlgorithm: ConflictAlgorithm.ignore);
    return count > 0;
  }

  Future<void> updateCrux(String url, String crux, String modelName, {String? concepts}) async {
    Database db = await database;
    await db.update(
      'articles',
      {
        'crux': crux,
        'crux_model': modelName,
        'concepts': concepts
      },
      where: 'url = ?',
      whereArgs: [url],
    );
  }

  Future<void> deleteArticle(String id) async {
    Database db = await database;
    await db.delete('articles', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes all articles and sources, then reseeds default sources.
  Future<void> clearAllData() async {
    Database db = await database;
    await db.delete('articles');
    await db.delete('sources');
    await _onCreate(db, 4);
  }

  // ── Bookmark operations ──────────────────────────────────────────────

  Future<void> toggleBookmark(String url) async {
    Database db = await database;
    await db.rawUpdate(
      'UPDATE articles SET is_bookmarked = 1 - is_bookmarked WHERE url = ?',
      [url],
    );
  }

  Future<List<Map<String, dynamic>>> getBookmarkedArticles() async {
    Database db = await database;
    return await db.query(
      'articles',
      where: 'is_bookmarked = 1',
      orderBy: 'fetched_at DESC',
    );
  }

  // ── Read status ──────────────────────────────────────────────────────

  Future<void> markAsRead(String url) async {
    Database db = await database;
    await db.update('articles', {'is_read': 1}, where: 'url = ?', whereArgs: [url]);
  }

  Future<void> clearReadHistory() async {
    Database db = await database;
    await db.update('articles', {'is_read': 0});
  }

  // ── Search ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchArticles(String query) async {
    Database db = await database;
    final pattern = '%$query%';
    return await db.query(
      'articles',
      where: 'title LIKE ? OR crux LIKE ?',
      whereArgs: [pattern, pattern],
      orderBy: 'fetched_at DESC',
    );
  }
}
