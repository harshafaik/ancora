import 'package:flutter_tts/flutter_tts.dart';

/// Reads article text aloud with play/pause/stop controls.
class ArticleTTS {
  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Initialise TTS engine with sensible defaults.
  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() => _isPlaying = false);
    _tts.setErrorHandler((_) => _isPlaying = false);
  }

  /// Read the given text. If [fromIndex] is provided, resume from that
  /// character offset.
  Future<void> speak(String text, {int fromIndex = 0}) async {
    if (_isPlaying) return;
    _isPlaying = true;

    if (fromIndex > 0 && fromIndex < text.length) {
      // flutter_tts doesn't support offset resume, so we speak the remainder.
      await _tts.speak(text.substring(fromIndex));
    } else {
      await _tts.speak(text);
    }
  }

  Future<void> pause() async {
    await _tts.pause();
    _isPlaying = false;
  }

  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
