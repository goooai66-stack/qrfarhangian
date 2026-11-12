import 'dart:math' as math;

import 'package:shamsi_date/shamsi_date.dart';

import '../../core/nutrition/nutrition_calculator.dart';
import '../../data/db/app_database.dart';

/// محدوده‌ی انتخابگرها.
const minHeightCm = 120.0;
const maxHeightCm = 220.0;
const minWeightKg = 30.0;
const maxWeightKg = 250.0;
const weightStep = 0.5;
const minAgeYears = 10;
const maxAgeYears = 100;

/// وضعیت فرم پروفایل؛ مشترک بین آنبوردینگ و ویرایش پروفایل.
class ProfileDraft {
  const ProfileDraft({
    this.sex,
    required this.birthDate,
    this.isPregnant = false,
    this.heightCm = 165,
    this.weightKg = 70,
    this.goalType = GoalType.lose,
    this.goalWeightKg = 65,
    this.weeklyRateKg = 0.5,
    this.activityLevel = ActivityLevel.light,
  });

  /// پیش‌فرض آنبوردینگ: ۳۰ ساله، ۱ فروردین.
  factory ProfileDraft.initial(DateTime now) {
    final j = Jalali.fromDateTime(now);
    return ProfileDraft(birthDate: Jalali(j.year - 30, 1, 1).toDateTime());
  }

  factory ProfileDraft.fromProfile(UserProfile p, {double? currentWeightKg}) =>
      ProfileDraft(
        sex: p.sex,
        birthDate: p.birthDate,
        isPregnant: p.isPregnant,
        heightCm: p.heightCm,
        weightKg: currentWeightKg ?? p.startWeightKg,
        goalType: p.goalType,
        goalWeightKg: p.goalWeightKg,
        weeklyRateKg: p.weeklyRateKg,
        activityLevel: p.activityLevel,
      );

  /// null تا وقتی کاربر انتخاب نکرده.
  final Sex? sex;
  final DateTime birthDate;
  final bool isPregnant;
  final double heightCm;
  final double weightKg;
  final GoalType goalType;
  final double goalWeightKg;
  final double weeklyRateKg;
  final ActivityLevel activityLevel;

  bool get isFemale => sex == Sex.female;
  bool get pregnant => isFemale && isPregnant;

  int age(DateTime now) => ageInYears(birthDate, now);

  double get bmi => calculateBmi(weightKg: weightKg, heightCm: heightCm);

  /// کمترین وزن هدف مجاز (BMI ۱۸٫۵)، گرد به بالا روی گام ۰٫۵.
  double get minGoalWeight =>
      (minHealthyWeightKg(heightCm) / weightStep).ceil() * weightStep;

  /// محدوده‌ی مجاز وزن هدف برای [goal]؛ null یعنی هیچ مقداری مجاز نیست.
  ({double min, double max})? goalWeightRange([GoalType? goal]) {
    switch (goal ?? goalType) {
      case GoalType.lose:
        final lo = math.max(minGoalWeight, minWeightKg);
        final hi = weightKg - weightStep;
        return hi >= lo ? (min: lo, max: hi) : null;
      case GoalType.gain:
        final lo = weightKg + weightStep;
        final hi = math.min(weightKg + 50, maxWeightKg);
        return hi >= lo ? (min: lo, max: hi) : null;
      case GoalType.maintain:
        return (min: weightKg, max: weightKg);
    }
  }

  /// چرا [goal] برای این کاربر مجاز نیست؟ (بخش ۶-۵)
  GoalBlockReason? blockReason(GoalType goal, DateTime now) {
    final r = goalBlockReason(
      goal: goal,
      age: age(now),
      isPregnant: pregnant,
      bmi: bmi,
    );
    if (r != null) return r;
    // جایی برای کاهش وزن تا BMI ۱۸٫۵ نیست.
    if (goal == GoalType.lose && goalWeightRange(GoalType.lose) == null) {
      return GoalBlockReason.lowBmi;
    }
    return null;
  }

  bool get isGoalWeightValid {
    final r = goalWeightRange();
    return r != null && goalWeightKg >= r.min && goalWeightKg <= r.max;
  }

  /// هدف و وزن هدف را با قوانین ایمنی و جهت هدف سازگار می‌کند.
  ProfileDraft normalized(DateTime now) {
    var goal = goalType;
    if (blockReason(goal, now) != null) goal = GoalType.maintain;
    final range = goalWeightRange(goal)!;
    var gw = goalWeightKg;
    if (goal == GoalType.maintain) {
      gw = weightKg;
    } else if (gw < range.min || gw > range.max) {
      // پیش‌فرض: ۵ کیلو در جهت هدف، داخل محدوده.
      final suggested = goal == GoalType.lose ? weightKg - 5 : weightKg + 5;
      gw = suggested.clamp(range.min, range.max);
    }
    return copyWith(
      goalType: goal,
      goalWeightKg: gw,
      isPregnant: isFemale && isPregnant,
    );
  }

  NutritionInput toInput() => NutritionInput(
    sex: sex ?? Sex.female,
    birthDate: birthDate,
    heightCm: heightCm,
    weightKg: weightKg,
    goalWeightKg: goalType == GoalType.maintain ? weightKg : goalWeightKg,
    activityLevel: activityLevel,
    goalType: goalType,
    weeklyRateKg: weeklyRateKg,
    isPregnant: pregnant,
  );

  NutritionPlan plan(DateTime now) => calculatePlan(toInput(), today: now);

  ProfileDraft copyWith({
    Sex? sex,
    DateTime? birthDate,
    bool? isPregnant,
    double? heightCm,
    double? weightKg,
    GoalType? goalType,
    double? goalWeightKg,
    double? weeklyRateKg,
    ActivityLevel? activityLevel,
  }) => ProfileDraft(
    sex: sex ?? this.sex,
    birthDate: birthDate ?? this.birthDate,
    isPregnant: isPregnant ?? this.isPregnant,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    goalType: goalType ?? this.goalType,
    goalWeightKg: goalWeightKg ?? this.goalWeightKg,
    weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
    activityLevel: activityLevel ?? this.activityLevel,
  );
}

/// فهرست مقدارها با گام مشخص (برای چرخ‌ها).
List<double> steppedValues(double min, double max, double step) {
  final n = ((max - min) / step).round();
  return [for (var i = 0; i <= n; i++) min + i * step];
}
