import 'package:calorie_lens/core/reminders/reminder_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('پیش‌فرض: همه خاموش', () {
    expect(planReminders(const ReminderSettings()), isEmpty);
    expect(const ReminderSettings().anyEnabled, isFalse);
  });

  test('وعده‌ها: سه یادآور روزانه با شناسه‌ی ثابت', () {
    final p = planReminders(const ReminderSettings(meals: true));
    expect(p.map((r) => r.id), [1, 2, 3]);
    expect(p.first.time, const TimeOfDayHM(8, 30));
    expect(p.every((r) => r.weekday == null), isTrue);
  });

  test('آب: هر ۲ ساعت از ۹ تا ۲۱', () {
    final p = planReminders(const ReminderSettings(water: true));
    expect(p.map((r) => r.time.hour), [9, 11, 13, 15, 17, 19, 21]);
    expect(p.map((r) => r.id).toSet(), hasLength(7));
    expect(p.every((r) => r.kind == ReminderKind.water), isTrue);
  });

  test('وزن: هفتگی، شنبه', () {
    final p = planReminders(const ReminderSettings(weight: true));
    expect(p.single.weekday, DateTime.saturday);
    expect(p.single.id, 40);
  });

  test('ذخیره و بازیابی', () {
    final s = const ReminderSettings(
      meals: true,
      water: true,
      weight: true,
    ).copyWith(lunch: const TimeOfDayHM(14, 15), waterEveryHours: 3);
    final d = ReminderSettings.decode(s.encode());
    expect(d.meals && d.water && d.weight, isTrue);
    expect(d.lunch, const TimeOfDayHM(14, 15));
    expect(d.waterEveryHours, 3);
  });

  test('داده‌ی خراب ← پیش‌فرض', () {
    expect(ReminderSettings.decode('{bad').meals, isFalse);
    expect(ReminderSettings.decode(null).anyEnabled, isFalse);
  });

  group('حالت رمضان', () {
    const r = ReminderSettings(
      ramadan: true,
      meals: true,
      water: true,
      suhoor: TimeOfDayHM(3, 30),
      iftar: TimeOfDayHM(18, 0),
    );
    test('سحر و افطار، بدون ناهار', () {
      final meals = planReminders(r).where((p) => p.kind != ReminderKind.water);
      expect(meals.map((p) => p.kind), [
        ReminderKind.suhoor,
        ReminderKind.iftar,
      ]);
      expect(meals.first.time, const TimeOfDayHM(3, 30));
    });
    test('آب بین افطار و سحر (از نیمه‌شب می‌گذرد)', () {
      final water = planReminders(r).where((p) => p.kind == ReminderKind.water);
      expect(water.map((p) => p.time.hour), [19, 21, 23, 1]);
    });
    test('ذخیره و بازیابی', () {
      final d = ReminderSettings.decode(r.encode());
      expect(d.ramadan, isTrue);
      expect(d.suhoor, const TimeOfDayHM(3, 30));
    });
  });
}
