import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 11, 9);

/// تاریخ تولد برای سن دقیق [age] در [today].
DateTime bornAge(int age) => DateTime(today.year - age, 1, 1);

NutritionInput input({
  Sex sex = Sex.female,
  int age = 30,
  double height = 165,
  double weight = 70,
  double goalWeight = 62,
  ActivityLevel activity = ActivityLevel.light,
  GoalType goal = GoalType.lose,
  double rate = 0.5,
  bool pregnant = false,
}) => NutritionInput(
  sex: sex,
  birthDate: bornAge(age),
  heightCm: height,
  weightKg: weight,
  goalWeightKg: goalWeight,
  activityLevel: activity,
  goalType: goal,
  weeklyRateKg: rate,
  isPregnant: pregnant,
);

void main() {
  group('ageInYears', () {
    test('قبل و بعد از تولد', () {
      final b = DateTime(1996, 5, 20);
      expect(ageInYears(b, DateTime(2026, 5, 19)), 29);
      expect(ageInYears(b, DateTime(2026, 5, 20)), 30);
      expect(ageInYears(b, DateTime(2026, 12, 1)), 30);
    });
  });

  group('BMR (Mifflin-St Jeor)', () {
    test('زن', () {
      // 10*70 + 6.25*165 − 5*30 − 161
      expect(
        calculateBmr(sex: Sex.female, weightKg: 70, heightCm: 165, age: 30),
        closeTo(1420.25, 1e-9),
      );
    });
    test('مرد', () {
      // 10*80 + 6.25*180 − 5*35 + 5
      expect(
        calculateBmr(sex: Sex.male, weightKg: 80, heightCm: 180, age: 35),
        closeTo(1755, 1e-9),
      );
    });
  });

  test('ضریب‌های فعالیت', () {
    expect(ActivityLevel.sedentary.factor, 1.2);
    expect(ActivityLevel.light.factor, 1.375);
    expect(ActivityLevel.moderate.factor, 1.55);
    expect(ActivityLevel.active.factor, 1.725);
    expect(ActivityLevel.veryActive.factor, 1.9);
    expect(calculateTdee(1000, ActivityLevel.moderate), closeTo(1550, 1e-9));
  });

  test('کسری روزانه', () {
    expect(dailyDeltaKcal(0.5), closeTo(550, 1e-9));
    expect(dailyDeltaKcal(0.25), closeTo(275, 1e-9));
    expect(dailyDeltaKcal(0.75), closeTo(825, 1e-9));
  });

  group('معیار پذیرش مرحله‌ی ۱', () {
    // زن، ۳۰ ساله، ۱۶۵ سانتی‌متر، ۷۰ کیلو، کم‌تحرک، کاهش ۰٫۵ کیلو در هفته
    final plan = calculatePlan(input(), today: today);

    test('کالری هدف = (BMR × 1.375) − 550', () {
      // BMR = 1420.25 → TDEE = 1952.84375 → هدف = 1402.84375 ≈ 1403
      expect(plan.bmr, closeTo(1420.25, 1e-9));
      expect(plan.tdee, closeTo(1952.84375, 1e-9));
      expect(plan.targetKcal, 1403);
      expect(plan.effectiveGoal, GoalType.lose);
      expect(plan.warnings, isEmpty);
    });

    test('درشت‌مغذی‌ها', () {
      expect(plan.proteinG, closeTo(112, 1e-9)); // 1.6 × 70
      expect(plan.fatG, closeTo(1403 * 0.25 / 9, 1e-9)); // ≈ 38.97
      expect(
        plan.carbsG,
        closeTo((1403 - 112 * 4 - (1403 * 0.25)) / 4, 1e-9),
      ); // ≈ 151.06
      final total = plan.proteinG * 4 + plan.carbsG * 4 + plan.fatG * 9;
      expect(total, closeTo(1403, 1e-6));
    });

    test('زمان رسیدن به هدف', () {
      // (1952.84 − 1403) × 7 / 7700 ≈ 0.4999 کیلو در هفته
      expect(plan.effectiveWeeklyRateKg, closeTo(0.5, 0.001));
      expect(plan.weeksToGoal, closeTo(16, 0.05)); // 8 کیلو ÷ 0.5
      final eta = plan.etaFrom(today)!;
      expect(eta.difference(today).inDays, inInclusiveRange(111, 113));
    });
  });

  group('درشت‌مغذی بر اساس هدف', () {
    test('ثابت: پروتئین 1.2 گرم', () {
      final p = calculatePlan(input(goal: GoalType.maintain), today: today);
      expect(p.targetKcal, p.tdee.round());
      expect(p.proteinG, closeTo(84, 1e-9));
      expect(p.weeksToGoal, isNull);
      expect(p.effectiveWeeklyRateKg, 0);
    });
    test('افزایش: پروتئین 1.8 گرم و مازاد', () {
      final p = calculatePlan(
        input(sex: Sex.male, goal: GoalType.gain, weight: 60, goalWeight: 66),
        today: today,
      );
      expect(p.targetKcal, (p.tdee + 550).round());
      expect(p.proteinG, closeTo(108, 1e-9));
      expect(p.weeksToGoal, closeTo(12, 0.05));
    });
  });

  group('کف ایمنی', () {
    test('زن: کمتر از ۱۲۰۰ نمی‌شود و هشدار می‌دهد', () {
      final p = calculatePlan(
        input(
          height: 150,
          weight: 58,
          goalWeight: 50,
          activity: ActivityLevel.sedentary,
          rate: 0.75,
          age: 50,
        ),
        today: today,
      );
      expect(p.targetKcal, 1200);
      expect(p.warnings, contains(PlanWarning.hitSafetyFloor));
      // سرعت واقعی کندتر از ۰٫۷۵ است.
      expect(p.effectiveWeeklyRateKg, lessThan(0.75));
    });
    test('مرد: کمتر از ۱۵۰۰ نمی‌شود', () {
      final p = calculatePlan(
        input(
          sex: Sex.male,
          height: 160,
          weight: 65,
          goalWeight: 60,
          activity: ActivityLevel.sedentary,
          rate: 0.75,
          age: 60,
        ),
        today: today,
      );
      expect(p.targetKcal, 1500);
      expect(p.warnings, contains(PlanWarning.hitSafetyFloor));
    });
    test('اگر حتی TDEE زیر کف باشد، زمان رسیدن نامعلوم است', () {
      final p = calculatePlan(
        input(
          height: 145,
          weight: 50,
          goalWeight: 47,
          activity: ActivityLevel.sedentary,
          age: 70,
        ),
        today: today,
      );
      expect(p.targetKcal, 1200);
      expect(p.effectiveWeeklyRateKg, 0);
      expect(p.weeksToGoal, isNull);
    });
  });

  group('هشدارهای ایمنی (بخش ۶-۵)', () {
    test('زیر ۱۸ سال: کاهش وزن غیرمجاز و تبدیل به تغذیه‌ی سالم', () {
      expect(
        goalBlockReason(
          goal: GoalType.lose,
          age: 17,
          isPregnant: false,
          bmi: 26,
        ),
        GoalBlockReason.minor,
      );
      final p = calculatePlan(input(age: 16), today: today);
      expect(p.effectiveGoal, GoalType.maintain);
      expect(p.requestedGoal, GoalType.lose);
      expect(p.targetKcal, p.tdee.round());
      expect(
        p.warnings,
        containsAll([
          PlanWarning.minorHealthyEatingOnly,
          PlanWarning.consultDoctor,
        ]),
      );
    });
    test('دقیقاً ۱۸ سال مجاز است', () {
      final p = calculatePlan(input(age: 18), today: today);
      expect(p.effectiveGoal, GoalType.lose);
    });
    test('زیر ۱۸ سال: افزایش وزن هم فقط تغذیه‌ی سالم', () {
      final p = calculatePlan(
        input(age: 15, goal: GoalType.gain, goalWeight: 75),
        today: today,
      );
      expect(p.effectiveGoal, GoalType.maintain);
    });
    test('باردار یا شیرده: بدون کسری', () {
      final p = calculatePlan(input(pregnant: true), today: today);
      expect(p.effectiveGoal, GoalType.maintain);
      expect(p.targetKcal, p.tdee.round());
      expect(
        p.warnings,
        containsAll([
          PlanWarning.pregnancyNoDeficit,
          PlanWarning.consultDoctor,
        ]),
      );
    });
    test('بارداری برای مرد نادیده گرفته می‌شود', () {
      final p = calculatePlan(
        input(sex: Sex.male, pregnant: true, weight: 90, goalWeight: 80),
        today: today,
      );
      expect(p.effectiveGoal, GoalType.lose);
    });
    test('BMI زیر ۱۸٫۵: کاهش وزن غیرمجاز', () {
      // 50 / 1.7² ≈ 17.3
      final p = calculatePlan(
        input(height: 170, weight: 50, goalWeight: 47),
        today: today,
      );
      expect(p.bmi, lessThan(18.5));
      expect(p.effectiveGoal, GoalType.maintain);
      expect(p.warnings, contains(PlanWarning.lowBmiNoLoss));
    });
    test('ثابت همیشه مجاز است', () {
      expect(
        goalBlockReason(
          goal: GoalType.maintain,
          age: 12,
          isPregnant: true,
          bmi: 15,
        ),
        isNull,
      );
    });
  });

  test('BMI و کمترین وزن سالم', () {
    expect(calculateBmi(weightKg: 70, heightCm: 165), closeTo(25.71, 0.01));
    expect(minHealthyWeightKg(165), closeTo(50.37, 0.01));
  });

  group('پیش‌بینی وزن', () {
    test('از شروع تا هدف', () {
      final pts = projectWeight(startKg: 70, goalKg: 62, weeklyRateKg: 0.5);
      expect(pts.first.weightKg, 70);
      expect(pts.last.weightKg, 62);
      expect(pts.last.week, closeTo(16, 1e-9));
      for (var i = 1; i < pts.length; i++) {
        expect(pts[i].weightKg, lessThanOrEqualTo(pts[i - 1].weightKg));
      }
    });
    test('تعداد نقطه محدود است', () {
      final pts = projectWeight(
        startKg: 150,
        goalKg: 70,
        weeklyRateKg: 0.25,
        maxPoints: 60,
      );
      expect(pts.length, lessThanOrEqualTo(62));
    });
    test('سرعت صفر', () {
      expect(
        projectWeight(startKg: 70, goalKg: 62, weeklyRateKg: 0),
        hasLength(1),
      );
    });
  });
}
