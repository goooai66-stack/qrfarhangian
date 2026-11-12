import 'package:calorie_lens/core/analytics/analytics.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingSender implements EventSender {
  @override
  Future<void> send(List<({String name, String day, int count})> events) =>
      Future.error(Exception('offline'));
}

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 11, 9, 10);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 11, 9, 10);
  });
  tearDown(() => db.close());

  test('شمارش در بافر محلی و ارسال دسته‌ای (فقط نام و تعداد)', () async {
    final sender = FakeEventSender();
    final a = AnalyticsService(db, sender, clock: () => now);
    await a.track(AnalyticsEvent.scan);
    await a.track(AnalyticsEvent.scan);
    await a.track(AnalyticsEvent.logFood);
    await a.flush();
    expect(sender.sent.toSet(), {
      (name: 'scan', day: '2026-11-09', count: 2),
      (name: 'log_food', day: '2026-11-09', count: 1),
    });
    await a.flush(); // بافر خالی شد
    expect(sender.sent, hasLength(2));
  });

  test('آفلاین ← بافر می‌ماند', () async {
    final a = AnalyticsService(db, _FailingSender(), clock: () => now);
    await a.track(AnalyticsEvent.scan);
    await a.flush();
    final ok = FakeEventSender();
    await AnalyticsService(db, ok, clock: () => now).flush();
    expect(ok.sent.single.count, 1);
  });

  test('خاموش ← هیچ رویدادی', () async {
    final sender = FakeEventSender();
    final a = AnalyticsService(db, sender, clock: () => now);
    await a.track(AnalyticsEvent.scan);
    await a.setEnabled(false);
    await a.track(AnalyticsEvent.scan);
    await a.flush();
    expect(sender.sent, isEmpty);
    expect(await a.isEnabled(), isFalse);
  });

  test('نگه‌داشت روز ۱، ۷ و ۳۰ — هر کدام یک‌بار', () async {
    final sender = FakeEventSender();
    final a = AnalyticsService(db, sender, clock: () => now);
    await a.onAppOpen(); // روز نصب
    for (final d in [1, 1, 3, 8, 9, 31, 50]) {
      now = DateTime(2026, 11, 9 + d, 10);
      await a.onAppOpen();
    }
    await a.flush();
    expect(sender.sent.map((e) => e.name).toList()..sort(), [
      'retention_d1',
      'retention_d30',
      'retention_d7',
    ]);
  });

  test('پنجره‌های نگه‌داشت', () {
    expect(retentionEventFor(0), isNull);
    expect(retentionEventFor(1), AnalyticsEvent.retentionD1);
    expect(retentionEventFor(2), isNull);
    expect(retentionEventFor(13), AnalyticsEvent.retentionD7);
    expect(retentionEventFor(44), AnalyticsEvent.retentionD30);
    expect(retentionEventFor(45), isNull);
  });
}
