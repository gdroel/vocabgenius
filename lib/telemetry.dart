import 'dart:convert';
import 'dart:io';

import 'package:purchases_flutter/purchases_flutter.dart';

/// Fire-and-forget product telemetry to the pipserver dashboard.
///
/// Events are keyed by the RevenueCat app_user_id (the same id RevenueCat
/// uses) so the dashboard can show a per-customer timeline. Every call is
/// best-effort: failures never throw and never block the UI.
class Telemetry {
  Telemetry._();

  static const String _baseUrl = 'https://vocabgenius-vx2s.onrender.com';

  /// The app was launched (RevenueCat is configured by this point).
  static void appOpened() => _send('app_opened');

  /// A paywall was shown to the user.
  static void paywallReached() => _send('paywall_reached');

  static Future<void> _send(String event) async {
    String? userId;
    try {
      userId = await Purchases.appUserID;
    } catch (_) {
      // RevenueCat not configured yet — send without an id; the server
      // records it under "anonymous".
    }
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse('$_baseUrl/client-event'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'userId': userId, 'event': event}));
      final response = await request.close();
      await response.drain<void>();
      client.close();
    } catch (_) {
      // Telemetry must never affect the app.
    }
  }
}
