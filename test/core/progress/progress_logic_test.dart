import 'package:calorie_lens/core/nutrition/nutrition_types.dart';
import 'package:calorie_lens/core/progress/badges.dart';
import 'package:calorie_lens/core/progress/rating_policy.dart';
import 'package:calorie_lens/core/progress/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 9);

  group('زنجیره', () {
    test('تا امروز', () {
      expect(
        currentStreak({'2026-11-07', '2026-11-08', '2026-11-09'}, today),
        3,
      );
    });
    test('امروز هنوز ثبت نشده ← تا دیروز حساب می‌شود', () {
      expect(currentStreak({'2026-11-07', '2026-11-08'}, today), 2);
    });
    test('یک روز فاصله ← زنجیره قطع', () {
      expect(currentStreak({'2026-11-06', '2026-11-07'}, today), 0);
      expect(currentStreak({}, today), 0);
    });
    test('عبور از ماه و سال', () {
      expect(
        currentStreak({'2025-12-31', '2026-01-01'}, DateTime(2026, 1, 1)),
        2,
      );
    });
    test('طولانی‌ترین', () {
      expect(
        longestStreak({
          '2026-10-01',
          '2026-10-02',
          '2026-10-03',
          '2026-10-05',
          '2026-10-06',
        }),
        3,
      );
      expect(longestStreak({}), 0);
    });
  });

  group('نشان‌ها', () {
    BadgeInputs inputs({
      int days = 0,
      int longest = 0,
      GoalType? goal = GoalType.lose,
      double? start = 70,
      List<double> weights = const [],
      int water = 0,
    }) => BadgeInputs(
      loggedDays: days,
      longestStreak: longest,
      goalType: goal,
      startWeightKg: start,
      weightsKg: weights,
      maxWaterGlasses: water,
    );

    test('هیچ', () => expect(earnedBadges(inputs()), isEmpty));
    test('اولین ثبت و زنجیره‌ها', () {
      expect(earnedBadges(inputs(days: 1, longest: 1)), {Achievement.firstLog});
      expect(earnedBadges(inputs(days: 7, longest: 7)), {
        Achievement.firstLog,
        Achievement.streak3,
        Achievement.streak7,
      });
    });
    test('اولین کیلو در جهت هدف', () {
      expect(earnedBadges(inputs(weights: [70, 69.5])), isEmpty);
      expect(earnedBadges(inputs(weights: [70, 69, 69.5])), {
        Achievement.firstKg,
      });
      expect(earnedBadges(inputs(goal: GoalType.gain, weights: [71])), {
        Achievement.firstKg,
      });
      // جهت مخالف هدف نشان نمی‌دهد.
      expect(earnedBadges(inputs(goal: GoalType.gain, weights: [69])), isEmpty);
      expect(
        earnedBadges(inputs(goal: GoalType.maintain, weights: [60])),
        isEmpty,
      );
    });
    test('۸ لیوان آب', () {
      expect(earnedBadges(inputs(water: 7)), isEmpty);
      expect(earnedBadges(inputs(water: 8)), {Achievement.water8});
    });
  });

  group('درخواست امتیاز', () {
    bool ask(int days, RatingState s, [DateTime? last]) => shouldAskForRating(
      loggedDays: days,
      state: s,
      lastAsked: last,
      now: today,
    );
    test('کمتر از ۳ روز ← نه', () => expect(ask(2, RatingState.none), isFalse));
    test('۳ روز ← بله', () => expect(ask(3, RatingState.none), isTrue));
    test('«بعداً» ← بعد از ۷ روز', () {
      expect(ask(5, RatingState.later, DateTime(2026, 11, 5)), isFalse);
      expect(ask(5, RatingState.later, DateTime(2026, 11, 2)), isTrue);
    });
    test('امتیاز داد یا «نه» ← هرگز', () {
      expect(ask(30, RatingState.done), isFalse);
      expect(ask(30, RatingState.never), isFalse);
    });
  });
}
