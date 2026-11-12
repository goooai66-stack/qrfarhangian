import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/features/onboarding/onboarding_screen.dart';
import 'package:calorie_lens/features/profile/profile_draft.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 9);

ProfileDraft draft({
  int age = 30,
  Sex sex = Sex.female,
  double height = 165,
  double weight = 70,
  GoalType goal = GoalType.lose,
  double goalWeight = 65,
  bool pregnant = false,
}) => ProfileDraft(
  sex: sex,
  birthDate: DateTime(now.year - age, 1, 1),
  heightCm: height,
  weightKg: weight,
  goalType: goal,
  goalWeightKg: goalWeight,
  isPregnant: pregnant,
);

void main() {
  test('پیش‌فرض آنبوردینگ ۳۰ ساله است', () {
    expect(ProfileDraft.initial(now).age(now), 30);
  });

  group('هدف غیرمجاز', () {
    test('زیر ۱۸ سال نمی‌تواند کاهش وزن بگذارد', () {
      final d = draft(age: 16);
      expect(d.blockReason(GoalType.lose, now), GoalBlockReason.minor);
      expect(d.blockReason(GoalType.gain, now), GoalBlockReason.minor);
      expect(d.blockReason(GoalType.maintain, now), isNull);
      final n = d.normalized(now);
      expect(n.goalType, GoalType.maintain);
      expect(n.toInput().goalWeightKg, n.weightKg);
    });
    test('باردار: کاهش وزن غیرمجاز', () {
      expect(
        draft(pregnant: true).blockReason(GoalType.lose, now),
        GoalBlockReason.pregnancy,
      );
    });
    test('مرد با isPregnant=true باردار حساب نمی‌شود', () {
      final d = draft(sex: Sex.male, pregnant: true, weight: 90);
      expect(d.blockReason(GoalType.lose, now), isNull);
      expect(d.normalized(now).isPregnant, isFalse);
    });
    test('BMI پایین: کاهش وزن غیرمجاز', () {
      final d = draft(height: 170, weight: 52);
      expect(d.blockReason(GoalType.lose, now), GoalBlockReason.lowBmi);
    });
    test('نزدیک مرز BMI که جای کاهش نیست', () {
      // حداقل وزن سالم برای ۱۶۵ ≈ ۵۰٫۴ → ۵۰٫۵؛ از ۵۰٫۵ جای کاهش نیست.
      final d = draft(weight: 50.5);
      expect(d.goalWeightRange(GoalType.lose), isNull);
      expect(d.blockReason(GoalType.lose, now), GoalBlockReason.lowBmi);
    });
  });

  group('وزن هدف', () {
    test('محدوده‌ی کاهش: از BMI ۱۸٫۵ تا کمی کمتر از وزن فعلی', () {
      final r = draft().goalWeightRange()!;
      expect(r.min, 50.5);
      expect(r.max, 69.5);
    });
    test('جهت اشتباه اصلاح می‌شود', () {
      final n = draft(goalWeight: 80).normalized(now);
      expect(n.goalWeightKg, 65);
      expect(n.isGoalWeightValid, isTrue);
    });
    test('افزایش وزن', () {
      final d = draft(goal: GoalType.gain, goalWeight: 60).normalized(now);
      expect(d.goalWeightKg, 75);
    });
  });

  test('قدم‌های آنبوردینگ', () {
    expect(visibleSteps(draft()), contains(OnboardingStep.pregnancy));
    expect(
      visibleSteps(draft(sex: Sex.male)),
      isNot(contains(OnboardingStep.pregnancy)),
    );
    final maintain = visibleSteps(draft(goal: GoalType.maintain));
    expect(maintain, isNot(contains(OnboardingStep.goalWeight)));
    expect(maintain, isNot(contains(OnboardingStep.rate)));
    expect(visibleSteps(draft()).last, OnboardingStep.result);
  });

  test('steppedValues', () {
    expect(steppedValues(1, 2, 0.5), [1, 1.5, 2]);
  });
}
