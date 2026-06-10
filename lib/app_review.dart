import 'package:flutter/services.dart';

/// Asks iOS to show the native App Store review prompt
/// (`SKStoreReviewController`). The system rate-limits whether it actually
/// appears, so this is best-effort and never throws into the UI.
class AppReview {
  // Reuses the existing native bridge channel handled in AppDelegate.
  static const _channel = MethodChannel('professor_pip/widget');

  static Future<void> request() async {
    try {
      await _channel.invokeMethod('requestAppReview');
    } catch (_) {
      // Channel only exists on iOS; ignore elsewhere.
    }
  }
}
