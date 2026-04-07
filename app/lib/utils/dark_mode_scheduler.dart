import 'package:shared_preferences/shared_preferences.dart';

/// Manages auto dark mode scheduling based on time of day.
///
/// Light mode is active during daytime hours (configurable),
/// dark mode during nighttime. Settings are persisted.
class DarkModeScheduler {
  static const String _enabledKey = 'darkModeScheduleEnabled';
  static const String _startHourKey = 'darkModeScheduleStart';
  static const String _endHourKey = 'darkModeScheduleEnd';

  /// Default dark mode hours: 7 PM (19) to 7 AM (7).
  static const int defaultStartHour = 19;
  static const int defaultEndHour = 7;

  /// Whether auto scheduling is enabled.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Enable or disable auto scheduling.
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// The hour (0-23) when dark mode starts.
  static Future<int> getStartHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_startHourKey) ?? defaultStartHour;
  }

  /// The hour (0-23) when light mode starts.
  static Future<int> getEndHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_endHourKey) ?? defaultEndHour;
  }

  /// Set the dark mode schedule hours.
  static Future<void> setHours(int start, int end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_startHourKey, start);
    await prefs.setInt(_endHourKey, end);
  }

  /// Returns whether it's currently "dark hours" based on schedule.
  static Future<bool> isCurrentlyDarkHours() async {
    final enabled = await isEnabled();
    if (!enabled) return false;

    final start = await getStartHour();
    final end = await getEndHour();
    final now = DateTime.now().hour;

    if (start > end) {
      // e.g., 19:00 to 07:00 (spans midnight)
      return now >= start || now < end;
    } else {
      // e.g., 20:00 to 05:00 (same day range)
      return now >= start && now < end;
    }
  }

  /// Returns a human-readable schedule description.
  static Future<String> getDescription() async {
    final start = await getStartHour();
    final end = await getEndHour();
    final startLabel = _formatHour(start);
    final endLabel = _formatHour(end);
    return 'Dark mode from $startLabel to $endLabel';
  }

  static String _formatHour(int hour) {
    if (hour == 0 || hour == 24) return 'midnight';
    if (hour == 12) return 'noon';
    final period = hour >= 12 ? 'PM' : 'AM';
    final display = hour > 12 ? hour - 12 : hour;
    return '$display $period';
  }
}
