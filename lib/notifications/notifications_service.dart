import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../topics/words_data.dart';

class NotificationsService {
  // A fixed id range for the daily "word of the day" notifications so the whole
  // batch can be cancelled and rescheduled together.
  static const _wordOfDayBaseId = 2000;
  static const _wordOfDayDays = 14;
  static const _wordOfDayHour = 10; // 10am local time
  static final NotificationsService instance = NotificationsService._();
  NotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestIosPermission() async {
    await init();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  /// Schedules a daily "word of the day" notification at 10am local time for
  /// the next [_wordOfDayDays] days, each showing a different random word drawn
  /// from the user's followed [topicIds]. iOS can't generate notification
  /// content on the fly, so we pre-fill a rolling window; call this again on
  /// app launch (and after onboarding) to refresh the words and top it up.
  ///
  /// Word of the day is a paid perk, so it is only scheduled when
  /// [hasActiveSubscription] is true. Calling this without an active
  /// subscription cancels any window left over from a lapsed subscription, so
  /// pass the current entitlement on every launch.
  ///
  /// iOS only delivers these once notification permission is granted, so it is
  /// safe to call regardless of permission state.
  Future<void> scheduleWordOfDay(
    Iterable<String> topicIds, {
    required bool hasActiveSubscription,
  }) async {
    await init();
    await cancelWordOfDay();
    if (!hasActiveSubscription) return;

    final pool = List<Word>.of(WordsData.forTopics(topicIds));
    if (pool.isEmpty) return;
    // Shuffle once so the window's words don't repeat until the pool is
    // exhausted (every followed pool is far larger than the window).
    pool.shuffle();

    // `tz.local` isn't configured (defaults to UTC), so we can't build "10am
    // local" from tz components directly. Instead build each fire time from a
    // device-local `DateTime` (which is already in the device's zone) and
    // convert it to its absolute instant. Constructing each day via the
    // calendar also keeps it at 10am wall-clock across DST transitions.
    final now = DateTime.now();
    var firstDay = DateTime(now.year, now.month, now.day, _wordOfDayHour);
    // If 10am has already passed today, start tomorrow.
    if (!firstDay.isAfter(now)) {
      firstDay = DateTime(now.year, now.month, now.day + 1, _wordOfDayHour);
    }

    for (var i = 0; i < _wordOfDayDays; i++) {
      final word = pool[i % pool.length];
      final local = DateTime(
        firstDay.year,
        firstDay.month,
        firstDay.day + i,
        _wordOfDayHour,
      );
      final fireAt = tz.TZDateTime.from(local, tz.local);
      await _plugin.zonedSchedule(
        _wordOfDayBaseId + i,
        '${word.word[0].toUpperCase()}${word.word.substring(1)}',
        '${word.partOfSpeech} · ${word.definition}',
        fireAt,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelWordOfDay() async {
    await init();
    for (var i = 0; i < _wordOfDayDays; i++) {
      await _plugin.cancel(_wordOfDayBaseId + i);
    }
  }
}
