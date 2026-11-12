/// آنالیتیکس بی‌نام (بخش ۱۱): فقط شمارش رویدادهای کلیدی در هر روز؛
/// هیچ داده‌ی شخصی، غذایی یا عددی از کاربر فرستاده نمی‌شود.
library;

import 'dart:convert';

import '../../data/db/app_database.dart';
import '../utils/jalali_date.dart';

enum AnalyticsEvent {
  onboardingCompleted('onboarding_completed'),
  scan('scan'),
  voiceLog('voice_log'),
  logFood('log_food'),
  paywallView('paywall_view'),
  purchase('purchase'),
  retentionD1('retention_d1'),
  retentionD7('retention_d7'),
  retentionD30('retention_d30');

  const AnalyticsEvent(this.wireName);
  final String wireName;
}

/// ارسال دسته‌ای به سرور (در تست جعلی).
abstract interface class EventSender {
  Future<void> send(List<({String name, String day, int count})> events);
}

class FakeEventSender implements EventSender {
  final sent = <({String name, String day, int count})>[];

  @override
  Future<void> send(
    List<({String name, String day, int count})> events,
  ) async => sent.addAll(events);
}

/// پنجره‌های نگه‌داشت: اولین بازگشت در روز ۱، روز ۷ تا ۱۳، روز ۳۰ تا ۴۴ بعد از نصب.
AnalyticsEvent? retentionEventFor(int daysSinceInstall) =>
    switch (daysSinceInstall) {
      1 => AnalyticsEvent.retentionD1,
      >= 7 && <= 13 => AnalyticsEvent.retentionD7,
      >= 30 && <= 44 => AnalyticsEvent.retentionD30,
      _ => null,
    };

class AnalyticsService {
  AnalyticsService(this._db, this._sender, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final EventSender _sender;
  final DateTime Function() _clock;

  static const enabledKey = 'analytics_enabled';
  static const _bufferKey = 'analytics_buffer';
  static const _installKey = 'install_day';
  static const _retentionKey = 'retention_sent';
  static const _maxBuffered = 500;

  Future<bool> isEnabled() async =>
      (await _db.getSetting(enabledKey)) != 'false';

  Future<void> setEnabled(bool v) async {
    await _db.setSetting(enabledKey, '$v');
    if (!v) await _db.setSetting(_bufferKey, '{}');
  }

  Future<Map<String, int>> _buffer() async {
    try {
      return (jsonDecode(await _db.getSetting(_bufferKey) ?? '{}') as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      );
    } catch (_) {
      return {};
    }
  }

  /// شمارش در بافر محلی («روز|رویداد» ← تعداد)؛ ارسال بعداً و آفلاین‌پذیر.
  Future<void> track(AnalyticsEvent e) async {
    if (!await isEnabled()) return;
    final b = await _buffer();
    if (b.length >= _maxBuffered) return;
    final k = '${dayKey(_clock())}|${e.wireName}';
    b[k] = (b[k] ?? 0) + 1;
    await _db.setSetting(_bufferKey, jsonEncode(b));
  }

  /// هنگام باز شدن اپ: ثبت روز نصب و رویداد نگه‌داشت (هر کدام یک‌بار).
  Future<void> onAppOpen() async {
    final today = dateOnly(_clock());
    final install = await _db.getSetting(_installKey);
    if (install == null) {
      await _db.setSetting(_installKey, dayKey(today));
      return;
    }
    final days = today.difference(parseDayKey(install)).inDays;
    final e = retentionEventFor(days);
    if (e == null) return;
    final sent = (await _db.getSetting(_retentionKey) ?? '').split(',');
    if (sent.contains(e.wireName)) return;
    await _db.setSetting(_retentionKey, [...sent, e.wireName].join(','));
    await track(e);
  }

  /// ارسال بافر؛ در صورت خطا (آفلاین) بافر می‌ماند.
  Future<void> flush() async {
    final b = await _buffer();
    if (b.isEmpty || !await isEnabled()) return;
    final events = [
      for (final e in b.entries)
        (name: e.key.split('|')[1], day: e.key.split('|')[0], count: e.value),
    ];
    try {
      await _sender.send(events);
      await _db.setSetting(_bufferKey, '{}');
    } catch (_) {}
  }
}
