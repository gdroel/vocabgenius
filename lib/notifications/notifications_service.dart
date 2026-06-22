import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../topics/words_data.dart';

class NotificationsService {
  static const _trialReminderId = 1001;

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

  Future<void> scheduleTrialReminder({Duration delay = const Duration(days: 2)}) async {
    await init();
    final fireAt = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      _trialReminderId,
      'Your Professor Pip starts tomorrow!',
      "You've learned 24 words in your first two days with me. Let's keep the ball rolling!",
      fireAt,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelTrialReminder() async {
    await init();
    await _plugin.cancel(_trialReminderId);
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

  // DEMO ONLY — fires five "word of the day" notifications a few seconds apart
  // so the experience can be shown live. Equanimous is delivered last. Remove
  // before shipping.
  static const _demoWordOfDayBaseId = 3000;
  static const List<List<String>> _demoWords = [
    ['Ephemeral', '(adj) Lasting for a very short time (The morning mist was ephemeral.)'],
    ['Sycophant', '(n) A person who flatters others to gain advantage (The king was surrounded by sycophants.)'],
    ['Quixotic', '(adj) Exceedingly idealistic and impractical (He had a quixotic plan to end all traffic.)'],
    ['Laconic', '(adj) Using very few words (Her laconic reply ended the conversation.)'],
    ['Equanimous', '(adj) Calm and in control of emotions (She remained equanimous during the crisis.)'],
  ];
  Future<void> scheduleDemoWordOfDay() async {
    await init();
    for (var i = 0; i < _demoWords.length; i++) {
      final fireAt =
          tz.TZDateTime.now(tz.local).add(Duration(seconds: 15 + i * 3));
      await _plugin.zonedSchedule(
        _demoWordOfDayBaseId + i,
        _demoWords[i][0],
        _demoWords[i][1],
        fireAt,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
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
