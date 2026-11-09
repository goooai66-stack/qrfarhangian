import 'package:calorie_lens/core/reminders/reminder_plan.dart';
import 'package:calorie_lens/core/reminders/reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  tz.Location tehran() => tz.getLocation('Asia/Tehran');

  tz.TZDateTime at(int d, int h, int m) =>
      tz.TZDateTime(tehran(), 2026, 11, d, h, m);

  test('روزانه: امروز اگر هنوز نگذشته، وگرنه فردا', () {
    const r = PlannedReminder(2, ReminderKind.lunch, TimeOfDayHM(13, 30));
    expect(LocalReminderScheduler.nextInstance(at(9, 10, 0), r), at(9, 13, 30));
    expect(
      LocalReminderScheduler.nextInstance(at(9, 13, 30), r),
      at(10, 13, 30),
    );
  });

  test('هفتگی: نزدیک‌ترین شنبه', () {
    // ۹ نوامبر ۲۰۲۶ دوشنبه است ← شنبه‌ی بعد ۱۴ نوامبر.
    const r = PlannedReminder(
      40,
      ReminderKind.weight,
      TimeOfDayHM(8, 0),
      weekday: DateTime.saturday,
    );
    final next = LocalReminderScheduler.nextInstance(at(9, 9, 0), r);
    expect(next, at(14, 8, 0));
    expect(next.weekday, DateTime.saturday);
  });
}
