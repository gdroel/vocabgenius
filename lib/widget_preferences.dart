import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user preferences that drive the iOS home-screen / lock-screen
/// widget cadence. The native widget reads this value out of the App Group's
/// UserDefaults and uses it to generate its TimelineEntries.
class WidgetPreferences {
  static const _kWordsPerDayKey = 'words_per_day';
  static const int defaultWordsPerDay = 12;
  static const int minWordsPerDay = 0;
  static const int maxWordsPerDay = 48;

  static const _channel = MethodChannel('professor_pip/widget');
  static int _wordsPerDay = defaultWordsPerDay;

  static int get wordsPerDay => _wordsPerDay;

  /// Hydrate from prefs and push the value to the widget. Call once during
  /// app startup.
  static void loadCached(SharedPreferences prefs) {
    _wordsPerDay = prefs.getInt(_kWordsPerDayKey) ?? defaultWordsPerDay;
    _pushWordsPerDay();
  }

  /// Saves the new cadence and reloads the widget timeline.
  static Future<void> setWordsPerDay(int value) async {
    final clamped = value.clamp(minWordsPerDay, maxWordsPerDay);
    if (clamped == _wordsPerDay) return;
    _wordsPerDay = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWordsPerDayKey, clamped);
    _pushWordsPerDay();
  }

  static void _pushWordsPerDay() {
    _channel
        .invokeMethod('setWordsPerDay', _wordsPerDay)
        .catchError((_) {});
  }
}
