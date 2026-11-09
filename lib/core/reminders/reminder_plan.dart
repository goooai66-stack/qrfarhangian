/// تنظیمات و برنامه‌ی یادآورها (بخش ۴-۵). منطق خالص و قابل تست؛
/// زمان‌بندی واقعی در [ReminderScheduler].
library;

import 'dart:convert';

enum ReminderKind { breakfast, lunch, dinner, water, weight }

class TimeOfDayHM {
  const TimeOfDayHM(this.hour, this.minute);
  final int hour;
  final int minute;

  Map<String, int> toJson() => {'h': hour, 'm': minute};
  factory TimeOfDayHM.fromJson(Map<String, dynamic> j) =>
      TimeOfDayHM(j['h'] as int, j['m'] as int);

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayHM && other.hour == hour && other.minute == minute;
  @override
  int get hashCode => Object.hash(hour, minute);
}

class ReminderSettings {
  const ReminderSettings({
    this.meals = false,
    this.breakfast = const TimeOfDayHM(8, 30),
    this.lunch = const TimeOfDayHM(13, 30),
    this.dinner = const TimeOfDayHM(20, 30),
    this.water = false,
    this.waterStartHour = 9,
    this.waterEndHour = 21,
    this.waterEveryHours = 2,
    this.weight = false,
    this.weightWeekday = DateTime.saturday,
    this.weightTime = const TimeOfDayHM(8, 0),
  });

  final bool meals;
  final TimeOfDayHM breakfast, lunch, dinner;
  final bool water;
  final int waterStartHour, waterEndHour, waterEveryHours;
  final bool weight;

  /// DateTime.saturday … DateTime.friday
  final int weightWeekday;
  final TimeOfDayHM weightTime;

  bool get anyEnabled => meals || water || weight;

  ReminderSettings copyWith({
    bool? meals,
    TimeOfDayHM? breakfast,
    TimeOfDayHM? lunch,
    TimeOfDayHM? dinner,
    bool? water,
    int? waterEveryHours,
    bool? weight,
    int? weightWeekday,
    TimeOfDayHM? weightTime,
  }) => ReminderSettings(
    meals: meals ?? this.meals,
    breakfast: breakfast ?? this.breakfast,
    lunch: lunch ?? this.lunch,
    dinner: dinner ?? this.dinner,
    water: water ?? this.water,
    waterStartHour: waterStartHour,
    waterEndHour: waterEndHour,
    waterEveryHours: waterEveryHours ?? this.waterEveryHours,
    weight: weight ?? this.weight,
    weightWeekday: weightWeekday ?? this.weightWeekday,
    weightTime: weightTime ?? this.weightTime,
  );

  String encode() => jsonEncode({
    'meals': meals,
    'breakfast': breakfast.toJson(),
    'lunch': lunch.toJson(),
    'dinner': dinner.toJson(),
    'water': water,
    'waterStart': waterStartHour,
    'waterEnd': waterEndHour,
    'waterEvery': waterEveryHours,
    'weight': weight,
    'weightDay': weightWeekday,
    'weightTime': weightTime.toJson(),
  });

  /// داده‌ی خراب یا قدیمی ← پیش‌فرض‌ها.
  static ReminderSettings decode(String? s) {
    if (s == null) return const ReminderSettings();
    try {
      final j = (jsonDecode(s) as Map).cast<String, dynamic>();
      TimeOfDayHM t(String k, TimeOfDayHM d) => j[k] == null
          ? d
          : TimeOfDayHM.fromJson((j[k] as Map).cast<String, dynamic>());
      const d = ReminderSettings();
      return ReminderSettings(
        meals: j['meals'] as bool? ?? false,
        breakfast: t('breakfast', d.breakfast),
        lunch: t('lunch', d.lunch),
        dinner: t('dinner', d.dinner),
        water: j['water'] as bool? ?? false,
        waterStartHour: j['waterStart'] as int? ?? d.waterStartHour,
        waterEndHour: j['waterEnd'] as int? ?? d.waterEndHour,
        waterEveryHours: j['waterEvery'] as int? ?? d.waterEveryHours,
        weight: j['weight'] as bool? ?? false,
        weightWeekday: j['weightDay'] as int? ?? d.weightWeekday,
        weightTime: t('weightTime', d.weightTime),
      );
    } catch (_) {
      return const ReminderSettings();
    }
  }
}

/// یک یادآور تکرارشونده: روزانه، یا هفتگی اگر [weekday] داده شود.
class PlannedReminder {
  const PlannedReminder(this.id, this.kind, this.time, {this.weekday});
  final int id;
  final ReminderKind kind;
  final TimeOfDayHM time;
  final int? weekday;

  @override
  String toString() =>
      'PlannedReminder($id, $kind, ${time.hour}:${time.minute}, $weekday)';
}

/// شناسه‌های ثابت اعلان‌ها (برای لغو و جایگزینی).
const _mealIds = {
  ReminderKind.breakfast: 1,
  ReminderKind.lunch: 2,
  ReminderKind.dinner: 3,
};
const _waterBaseId = 10;
const _weightId = 40;

List<PlannedReminder> planReminders(ReminderSettings s) => [
  if (s.meals) ...[
    PlannedReminder(
      _mealIds[ReminderKind.breakfast]!,
      ReminderKind.breakfast,
      s.breakfast,
    ),
    PlannedReminder(_mealIds[ReminderKind.lunch]!, ReminderKind.lunch, s.lunch),
    PlannedReminder(
      _mealIds[ReminderKind.dinner]!,
      ReminderKind.dinner,
      s.dinner,
    ),
  ],
  if (s.water)
    for (
      var h = s.waterStartHour, i = 0;
      h <= s.waterEndHour && i < 20;
      h += s.waterEveryHours.clamp(1, 12), i++
    )
      PlannedReminder(_waterBaseId + i, ReminderKind.water, TimeOfDayHM(h, 0)),
  if (s.weight)
    PlannedReminder(
      _weightId,
      ReminderKind.weight,
      s.weightTime,
      weekday: s.weightWeekday,
    ),
];
