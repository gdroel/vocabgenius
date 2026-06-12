import 'dart:convert';
import 'dart:io';

import 'billing/billing_service.dart';

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

  /// The user reached the notification screen (tapped a push).
  static void notificationScreen() => _send('notification_screen');

  /// The user granted notification permission (first allow).
  static void notificationsEnabled() => _send('notifications_enabled');

  /// The user started the annual free trial.
  static void annualTrialStarted() => _send('annual_trial_started');

  /// The user started the monthly plan (from the notification paywall).
  static void monthlyStarted() => _send('monthly_started');

  /// The user bought the lifetime plan (from the lifetime paywall).
  static void lifetimePurchased() => _send('lifetime_purchased');

  /// The user entered their name during onboarding; [name] is sent as the
  /// event value.
  static void nameEntered(String name) => _send('name_entered', value: name);

  static Future<void> _send(String event, {String? value}) async {
    // Safe even before RevenueCat is configured: returns null rather than
    // crashing the SDK. A null id is recorded as "anonymous" server-side.
    final userId = await BillingService.currentAppUserId();
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse('$_baseUrl/client-event'));
      request.headers.contentType = ContentType.json;
      final body = <String, dynamic>{'userId': userId, 'event': event};
      if (value != null) body['value'] = value;
      request.write(jsonEncode(body));
      final response = await request.close();
      await response.drain<void>();
      client.close();
    } catch (_) {
      // Telemetry must never affect the app.
    }
  }
}
