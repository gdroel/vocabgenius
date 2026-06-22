import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'billing/billing_service.dart';

/// Fire-and-forget product telemetry to the pipserver dashboard.
///
/// Events are keyed by the RevenueCat app_user_id (the same id RevenueCat
/// uses) so the dashboard can show a per-customer timeline. Every call is
/// best-effort: failures never throw and never block the UI.
class Telemetry {
  Telemetry._();

  static const String _baseUrl = 'https://vocabgenius-vx2s.onrender.com';

  // Reuses the widget method channel to ask native iOS which StoreKit
  // environment this build runs in — "sandbox" for Xcode/TestFlight, "production"
  // for the App Store. This is the same Sandbox/Production split Apple stamps on
  // its server notifications, so the dashboard can filter client telemetry down
  // to real users instead of our own testing.
  static const MethodChannel _channel = MethodChannel('professor_pip/widget');

  // Resolved once and cached — the environment can't change within a run.
  static String? _environment;

  static Future<String> _resolveEnvironment() async {
    final cached = _environment;
    if (cached != null) return cached;
    // Build mode is the fallback when the native channel is unavailable (e.g.
    // Android) or the call fails: release builds map to production, else sandbox.
    final fallback = kReleaseMode ? 'production' : 'sandbox';
    String env;
    try {
      env = await _channel.invokeMethod<String>('storeEnvironment') ?? fallback;
    } catch (_) {
      env = fallback;
    }
    return _environment = env;
  }

  /// The app was launched (RevenueCat is configured by this point).
  static void appOpened() => _send('app_opened');

  /// The app was sent to the background — our best proxy for the user closing
  /// it (iOS can't reliably deliver a network call on actual termination).
  static void appClosed() => _send('app_closed');

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

  /// An onboarding step was completed. [step] is the step's screen name (e.g.
  /// "Onboarding-13-VocabLevel") and [value], when present, is what the user
  /// selected on it (a choice, or a comma-joined list of choices).
  static void onboardingStep(String step, {String? value}) =>
      _send('onboarding_step', value: value, step: step);

  static Future<void> _send(String event, {String? value, String? step}) async {
    // Safe even before RevenueCat is configured: returns null rather than
    // crashing the SDK. A null id is recorded as "anonymous" server-side.
    final userId = await BillingService.currentAppUserId();
    final environment = await _resolveEnvironment();
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse('$_baseUrl/client-event'));
      request.headers.contentType = ContentType.json;
      final body = <String, dynamic>{
        'userId': userId,
        'event': event,
        'environment': environment,
      };
      if (value != null) body['value'] = value;
      if (step != null) body['step'] = step;
      request.write(jsonEncode(body));
      final response = await request.close();
      await response.drain<void>();
      client.close();
    } catch (_) {
      // Telemetry must never affect the app.
    }
  }
}
