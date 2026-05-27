import 'package:shared_preferences/shared_preferences.dart';

/// Persistent store for the user's name, set during onboarding and read by
/// Pip's speech bubbles across the app so Pip can address the user directly.
class UserProfile {
  static const _kNameKey = 'user_name';
  static String _name = '';

  /// First name only, trimmed. Empty string if unset (user skipped name step).
  static String get firstName {
    if (_name.isEmpty) return '';
    return _name.split(RegExp(r'\s+')).first;
  }

  /// Loads the cached name. Call once during app startup before the first
  /// frame so speech bubbles render with the right name on cold start.
  static void loadCached(SharedPreferences prefs) {
    _name = prefs.getString(_kNameKey)?.trim() ?? '';
  }

  /// Persists the name. Called from the onboarding name step on every change.
  static Future<void> save(String name) async {
    final trimmed = name.trim();
    if (trimmed == _name) return;
    _name = trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_kNameKey);
    } else {
      await prefs.setString(_kNameKey, trimmed);
    }
  }
}
