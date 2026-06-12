import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'billing/billing_service.dart';
import 'billing/paywall_screen.dart';
import 'telemetry.dart';

/// Bridges native APNs push to Flutter:
///   - receives the device token from iOS and registers it on the server
///     (keyed by the RevenueCat app_user_id, the same id everything else uses),
///   - navigates to the fixed "hello there" screen when a notification is
///     tapped (cold-start or warm).
///
/// All networking is best-effort and never throws into the UI.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _baseUrl = 'https://vocabgenius-vx2s.onrender.com';
  static const MethodChannel _channel = MethodChannel('professor_pip/push');

  String? _pendingToken;
  bool _notifiedEnabled = false;

  Future<void> init() async {
    _channel.setMethodCallHandler(_onNativeCall);
    // When RevenueCat finishes configuring, register any token we're holding
    // under the now-available app user id.
    BillingService.onRevenueCatConfigured = _registerPending;
    // Pull anything that arrived before the handler was attached: a device
    // token already issued, and a route if the app was cold-started by a tap.
    try {
      final token = await _channel.invokeMethod<String>('getDeviceToken');
      if (token != null && token.isNotEmpty) _onToken(token);
    } catch (_) {}
    try {
      final route = await _channel.invokeMethod<String>('getInitialRoute');
      if (route != null && route.isNotEmpty) _navigate(route);
    } catch (_) {}
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onToken':
        final token = call.arguments as String?;
        if (token != null && token.isNotEmpty) _onToken(token);
        break;
      case 'onNotificationTap':
        _navigate(call.arguments as String? ?? 'hello');
        break;
    }
    return null;
  }

  /// Called from the onboarding (and paywall) opt-in once the user grants
  /// notification permission. Fires the one-time "enabled" event and asks iOS
  /// for an APNs token so server-driven pushes can deliver.
  void onNotificationsGranted() {
    if (!_notifiedEnabled) {
      _notifiedEnabled = true;
      Telemetry.notificationsEnabled();
    }
    _channel
        .invokeMethod('registerForRemoteNotifications')
        .catchError((_) {});
  }

  void _onToken(String token) {
    _pendingToken = token;
    _registerPending();
  }

  void _navigate(String route) {
    // The push payload's route selects which offer paywall to open. Anything
    // other than the explicit "lifetime" route (including the legacy "hello"
    // value) opens the monthly offer, preserving older notifications.
    final offer =
        route == 'lifetime' ? PaywallOffer.lifetime : PaywallOffer.monthly;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => OfferPaywallScreen(offer: offer)),
    );
  }

  /// Register the held device token, but only once we have a real app user id.
  /// If RevenueCat isn't configured yet this is a no-op; it runs again from the
  /// onRevenueCatConfigured hook.
  Future<void> _registerPending() async {
    final token = _pendingToken;
    if (token == null) return;
    final userId = await BillingService.currentAppUserId();
    if (userId == null) return; // not configured yet — retry on configure
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request =
          await client.postUrl(Uri.parse('$_baseUrl/register-device'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'userId': userId, 'deviceToken': token}));
      final response = await request.close();
      await response.drain<void>();
      client.close();
    } catch (_) {
      // Best-effort: a failed registration must not affect the app.
    }
  }
}
