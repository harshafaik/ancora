import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/feed_screen.dart';

/// Entry point — initialises Flutter bindings and launches the app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AncoraApp());
}

/// Root widget.
///
/// Manages app-wide theme (light/dark with dynamic colour), font size,
/// and font family — all persisted via SharedPreferences.
class AncoraApp extends StatefulWidget {
  const AncoraApp({super.key});

  @override
  State<AncoraApp> createState() => _AncoraAppState();
}

class _AncoraAppState extends State<AncoraApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  double _fontSize = 17.0;
  String _fontFamily = 'Roboto';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Restores theme, font size, and font family from local storage.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 2; // Default to dark
    final savedFontSize = prefs.getDouble('fontSize') ?? 17.0;
    final savedFontFamily = prefs.getString('fontFamily') ?? 'Roboto';
    setState(() {
      _themeMode = ThemeMode.values[themeIndex];
      _fontSize = savedFontSize;
      _fontFamily = savedFontFamily;
    });
  }

  /// Toggles between light and dark mode, persisting the choice.
  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      prefs.setInt('themeMode', _themeMode.index);
    });
  }

  /// Persists the global font size.
  Future<void> _updateFontSize(double newSize) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = newSize;
      prefs.setDouble('fontSize', newSize);
    });
  }

  /// Persists the global font family.
  Future<void> _updateFontFamily(String newFamily) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontFamily = newFamily;
      prefs.setString('fontFamily', newFamily);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Ancora',
          themeMode: _themeMode,
          theme: ThemeData(
            colorScheme:
                lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkDynamic ??
                ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.dark,
                ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.black,
            cardTheme: const CardThemeData(
              color: Color(0xFF1A1A1A),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          home: FeedScreen(
            onThemeToggle: _toggleTheme,
            currentThemeMode: _themeMode,
            fontSize: _fontSize,
            fontFamily: _fontFamily,
            onFontSizeChanged: _updateFontSize,
            onFontFamilyChanged: _updateFontFamily,
          ),
        );
      },
    );
  }
}
