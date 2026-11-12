/// محاسبات تغذیه طبق بخش ۶ سند. تابع‌های خالص و بدون وابستگی به UI.
library;

import 'dart:math' as math;

import 'nutrition_types.dart';

export 'nutrition_types.dart';

/// هر کیلو چربی ≈ ۷۷۰۰ کیلوکالری.
const kcalPerKgFat = 7700.0;
const kcalPerGramProtein = 4.0;
const kcalPerGramCarbs = 4.0;
const kcalPerGramFat = 9.0;
const fatShareOfKcal = 0.25;
const minBmiForWeightLoss = 18.5;
const adultAge = 18;

/// کف ایمنی کالری روزانه (بخش ۶-۳).
int safetyFloorKcal(Sex sex) => sex == Sex.female ? 1200 : 1500;

/// سن کامل (سال) در تاریخ [on].
int ageInYears(DateTime birthDate, DateTime on) {
  var age = on.year - birthDate.year;
  if (on.month < birthDate.month ||
      (on.month == birthDate.month && on.day < birthDate.day)) {
    age--;
  }
  return age;
}

/// متابولیسم پایه — Mifflin-St Jeor (بخش ۶-۱).
double calculateBmr({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return sex == Sex.male ? base + 5 : base - 161;
}

/// کالری نگه‌داری (بخش ۶-۲).
double calculateTdee(double bmr, ActivityLevel level) => bmr * level.factor;

/// کسری یا مازاد روزانه برای سرعت [weeklyRateKg] (بخش ۶-۳).
double dailyDeltaKcal(double weeklyRateKg) => weeklyRateKg * kcalPerKgFat / 7;

double calculateBmi({required double weightKg, required double heightCm}) {
  final m = heightCm / 100;
  return weightKg / (m * m);
}

/// کمترین وزنی که BMI آن ۱۸٫۵ است؛ وزن هدف کاهشی نباید کمتر از این باشد.
double minHealthyWeightKg(double heightCm) {
  final m = heightCm / 100;
  return minBmiForWeightLoss * m * m;
}

/// دلیل‌هایی که یک هدف را غیرمجاز می‌کنند (بخش ۶-۵).
enum GoalBlockReason {
  /// زیر ۱۸ سال: فقط «تغذیه‌ی سالم».
  minor,

  /// باردار یا شیرده: کسری کالری ممنوع.
  pregnancy,

  /// BMI زیر ۱۸٫۵: کاهش وزن ممنوع.
  lowBmi,
}

/// هشدارهای صفحه‌ی نتیجه.
enum PlanWarning {
  /// هدف به کف ایمنی رسید؛ سرعت کمتری انتخاب شود.
  hitSafetyFloor,

  /// هدف درخواستی به‌خاطر سن به «تغذیه‌ی سالم» تغییر کرد.
  minorHealthyEatingOnly,

  /// به‌خاطر بارداری/شیردهی کسری حذف شد.
  pregnancyNoDeficit,

  /// به‌خاطر BMI پایین کاهش وزن حذف شد.
  lowBmiNoLoss,

  /// توصیه‌ی مشورت با پزشک.
  consultDoctor,
}

/// اگر [goal] برای این شرایط مجاز نیست، دلیلش را برمی‌گرداند.
GoalBlockReason? goalBlockReason({
  required GoalType goal,
  required int age,
  required bool isPregnant,
  required double bmi,
}) {
  if (goal == GoalType.maintain) return null;
  if (age < adultAge) return GoalBlockReason.minor;
  if (goal == GoalType.lose) {
    if (isPregnant) return GoalBlockReason.pregnancy;
    if (bmi < minBmiForWeightLoss) return GoalBlockReason.lowBmi;
  }
  return null;
}

class NutritionInput {
  const NutritionInput({
    required this.sex,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    required this.goalWeightKg,
    required this.activityLevel,
    required this.goalType,
    required this.weeklyRateKg,
    this.isPregnant = false,
  });

  final Sex sex;
  final DateTime birthDate;
  final double heightCm;
  final double weightKg;
  final double goalWeightKg;
  final ActivityLevel activityLevel;
  final GoalType goalType;
  final double weeklyRateKg;

  /// باردار یا شیرده (فقط برای زن معنا دارد).
  final bool isPregnant;
}

class NutritionPlan {
  const NutritionPlan({
    required this.age,
    required this.bmi,
    required this.bmr,
    required this.tdee,
    required this.requestedGoal,
    required this.effectiveGoal,
    required this.targetKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.effectiveWeeklyRateKg,
    required this.weeksToGoal,
    required this.warnings,
  });

  final int age;
  final double bmi;
  final double bmr;
  final double tdee;
  final GoalType requestedGoal;

  /// هدفی که بعد از اعمال قوانین ایمنی اجرا می‌شود.
  final GoalType effectiveGoal;
  final int targetKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  /// سرعت واقعی بعد از کف ایمنی (کیلو در هفته، همیشه مثبت؛ برای ثابت صفر).
  final double effectiveWeeklyRateKg;

  /// null یعنی هدف «ثابت» است یا رسیدن ممکن نیست.
  final double? weeksToGoal;
  final List<PlanWarning> warnings;

  /// تاریخ تقریبی رسیدن به هدف از [from].
  DateTime? etaFrom(DateTime from) => weeksToGoal == null
      ? null
      : from.add(Duration(days: (weeksToGoal! * 7).ceil()));
}

/// برنامه‌ی کامل (بخش ۶-۳ تا ۶-۵).
NutritionPlan calculatePlan(NutritionInput input, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final age = ageInYears(input.birthDate, now);
  final pregnant = input.sex == Sex.female && input.isPregnant;
  final bmi = calculateBmi(weightKg: input.weightKg, heightCm: input.heightCm);
  final bmr = calculateBmr(
    sex: input.sex,
    weightKg: input.weightKg,
    heightCm: input.heightCm,
    age: age,
  );
  final tdee = calculateTdee(bmr, input.activityLevel);

  final warnings = <PlanWarning>[];
  var goal = input.goalType;
  switch (goalBlockReason(
    goal: goal,
    age: age,
    isPregnant: pregnant,
    bmi: bmi,
  )) {
    case GoalBlockReason.minor:
      warnings.add(PlanWarning.minorHealthyEatingOnly);
      goal = GoalType.maintain;
    case GoalBlockReason.pregnancy:
      warnings.add(PlanWarning.pregnancyNoDeficit);
      goal = GoalType.maintain;
    case GoalBlockReason.lowBmi:
      warnings.add(PlanWarning.lowBmiNoLoss);
      goal = GoalType.maintain;
    case null:
      break;
  }
  if (age < adultAge || pregnant) warnings.add(PlanWarning.consultDoctor);

  final delta = dailyDeltaKcal(input.weeklyRateKg);
  var target = switch (goal) {
    GoalType.lose => tdee - delta,
    GoalType.maintain => tdee,
    GoalType.gain => tdee + delta,
  };

  final floor = safetyFloorKcal(input.sex).toDouble();
  if (target < floor) {
    target = floor;
    if (goal == GoalType.lose) warnings.add(PlanWarning.hitSafetyFloor);
  }
  final targetKcal = target.round();

  // درشت‌مغذی‌ها (بخش ۶-۴)
  final proteinPerKg = switch (goal) {
    GoalType.lose => 1.6,
    GoalType.gain => 1.8,
    GoalType.maintain => 1.2,
  };
  final proteinG = proteinPerKg * input.weightKg;
  final fatG = targetKcal * fatShareOfKcal / kcalPerGramFat;
  final carbsG = math.max(
    0.0,
    (targetKcal - proteinG * kcalPerGramProtein - fatG * kcalPerGramFat) /
        kcalPerGramCarbs,
  );

  // سرعت واقعی (اگر کف ایمنی اعمال شد، کندتر از درخواست است).
  final effectiveRate = math.max(0.0, switch (goal) {
    GoalType.lose => (tdee - targetKcal) * 7 / kcalPerKgFat,
    GoalType.gain => (targetKcal - tdee) * 7 / kcalPerKgFat,
    GoalType.maintain => 0.0,
  });
  final distance = (input.weightKg - input.goalWeightKg).abs();
  final directionOk = switch (goal) {
    GoalType.lose => input.goalWeightKg < input.weightKg,
    GoalType.gain => input.goalWeightKg > input.weightKg,
    GoalType.maintain => false,
  };
  final weeks = directionOk && effectiveRate > 0
      ? distance / effectiveRate
      : null;

  return NutritionPlan(
    age: age,
    bmi: bmi,
    bmr: bmr,
    tdee: tdee,
    requestedGoal: input.goalType,
    effectiveGoal: goal,
    targetKcal: targetKcal,
    proteinG: proteinG,
    carbsG: carbsG,
    fatG: fatG,
    effectiveWeeklyRateKg: effectiveRate,
    weeksToGoal: weeks,
    warnings: warnings,
  );
}

/// نقطه‌های پیش‌بینی وزن هفته‌به‌هفته (برای نمودار صفحه‌ی نتیجه).
List<({double week, double weightKg})> projectWeight({
  required double startKg,
  required double goalKg,
  required double weeklyRateKg,
  int maxPoints = 60,
}) {
  if (weeklyRateKg <= 0 || startKg == goalKg) {
    return [(week: 0, weightKg: startKg)];
  }
  final weeks = (startKg - goalKg).abs() / weeklyRateKg;
  final sign = goalKg < startKg ? -1 : 1;
  final step = math.max(1.0, (weeks / maxPoints).ceilToDouble());
  final points = <({double week, double weightKg})>[];
  for (var w = 0.0; w < weeks; w += step) {
    points.add((week: w, weightKg: startKg + sign * weeklyRateKg * w));
  }
  points.add((week: weeks, weightKg: goalKg));
  return points;
}
