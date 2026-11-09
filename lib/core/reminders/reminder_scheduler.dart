import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// متن هر نوع یادآور (از فایل ترجمه).
typedef ReminderTexts = Map<ReminderKind, ({String title, String body})>;

abstract interface class ReminderScheduler {
  /// اجازه‌ی اعلان (اندروید ۱۳+). false یعنی کاربر نداد.
  Future<bool> requestPermission();

  /// همه‌ی یادآورهای قبلی لغو و طبق [settings] دوباره زمان‌بندی می‌شوند.
  Future<void> apply(ReminderSettings settings, ReminderTexts texts);
}

/// زمان‌بندی با flutter_local_notifications، به وقت محلی گوشی.
class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'reminders';
  static const _channelName = 'یادآورها';

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await _init();
    return await _android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> apply(ReminderSettings settings, ReminderTexts texts) async {
    await _init();
    await _plugin.cancelAll();
    final plan = planReminders(settings);
    if (plan.isEmpty) return;
    // دقیق اگر اجازه هست؛ وگرنه تقریبی (ممکن است چند دقیقه دیرتر بیاید).
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final r in plan) {
      final text = texts[r.kind]!;
      await _plugin.zonedSchedule(
        id: r.id,
        title: text.title,
        body: text.body,
        scheduledDate: nextInstance(tz.TZDateTime.now(tz.local), r),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: mode,
        matchDateTimeComponents: r.weekday == null
            ? DateTimeComponents.time
            : DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// نزدیک‌ترین زمان آینده برای یادآور (روزانه یا هفتگی).
  @visibleForTesting
  static tz.TZDateTime nextInstance(tz.TZDateTime now, PlannedReminder r) {
    var t = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      r.time.hour,
      r.time.minute,
    );
    while (!t.isAfter(now) || (r.weekday != null && t.weekday != r.weekday)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }
}

class FakeReminderScheduler implements ReminderScheduler {
  bool permission = true;
  ReminderSettings? applied;
  ReminderTexts? texts;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> apply(ReminderSettings settings, ReminderTexts texts) async {
    applied = settings;
    this.texts = texts;
  }
}
