/// پنج نشان اولیه (بخش ۴-۵). بدون زبان شرم‌آور؛ نشان قفل فقط «هنوز نه».
library;

import '../nutrition/nutrition_types.dart';

enum Achievement {
  /// اولین غذای ثبت‌شده.
  firstLog,

  /// ۳ روز پیاپی.
  streak3,

  /// ۷ روز پیاپی.
  streak7,

  /// اولین کیلو در جهت هدف (کم یا زیاد).
  firstKg,

  /// ۸ لیوان آب در یک روز.
  water8,
}

const waterGoalGlasses = 8;

class BadgeInputs {
  const BadgeInputs({
    required this.loggedDays,
    required this.longestStreak,
    required this.goalType,
    required this.startWeightKg,
    required this.weightsKg,
    required this.maxWaterGlasses,
  });

  final int loggedDays;
  final int longestStreak;
  final GoalType? goalType;
  final double? startWeightKg;
  final List<double> weightsKg;
  final int maxWaterGlasses;
}

Set<Achievement> earnedBadges(BadgeInputs i) {
  final start = i.startWeightKg;
  final firstKg =
      start != null &&
      i.weightsKg.isNotEmpty &&
      switch (i.goalType) {
        GoalType.lose =>
          start - i.weightsKg.reduce((a, b) => a < b ? a : b) >= 1,
        GoalType.gain =>
          i.weightsKg.reduce((a, b) => a > b ? a : b) - start >= 1,
        _ => false,
      };
  return {
    if (i.loggedDays >= 1) Achievement.firstLog,
    if (i.longestStreak >= 3) Achievement.streak3,
    if (i.longestStreak >= 7) Achievement.streak7,
    if (firstKg) Achievement.firstKg,
    if (i.maxWaterGlasses >= waterGoalGlasses) Achievement.water8,
  };
}
