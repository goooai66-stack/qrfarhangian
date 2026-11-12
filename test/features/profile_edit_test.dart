import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester, NutritionInput input) =>
      tester.runAsync(
        () => ProfileRepository(db).saveOnboarding(input, calculatePlan(input)),
      );

  Future<void> openEdit(WidgetTester tester) async {
    await pumpApp(tester, db, onboardingDone: true);
    await tester.tap(find.text('پروفایل'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('profile-edit')));
    await settle(tester);
  }

  testWidgets('ویرایش سطح فعالیت ← محاسبه‌ی دوباره و ذخیره', (tester) async {
    await seed(
      tester,
      NutritionInput(
        sex: Sex.female,
        birthDate: DateTime(DateTime.now().year - 30, 1, 1),
        heightCm: 165,
        weightKg: 70,
        goalWeightKg: 62,
        activityLevel: ActivityLevel.light,
        goalType: GoalType.lose,
        weeklyRateKg: 0.5,
      ),
    );
    await openEdit(tester);
    String preview() =>
        tester.widget<Text>(find.byKey(const Key('edit-preview'))).data!;
    Future<void> showPreview() => tester.scrollUntilVisible(
      find.byKey(const Key('edit-preview')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await showPreview();
    expect(preview(), 'کالری روزانه با این تغییرات: ۱٬۴۰۳');

    await tester.tap(find.text('کم‌تحرک'));
    await settle(tester);
    await tester.tap(find.text('متوسط').last);
    await settle(tester);
    // (1420.25 × 1.55) − 550 = 1651.39 ≈ 1651
    await showPreview();
    expect(preview(), 'کالری روزانه با این تغییرات: ۱٬۶۵۱');

    await tester.tap(find.byKey(const Key('profile-save')));
    await settle(tester);
    final goal = await tester.runAsync(
      () => ProfileRepository(db).watchActiveGoal().first,
    );
    expect(goal!.kcal, 1651);
    await disposeApp(tester);
  });

  testWidgets('زیر ۱۸ سال: گزینه‌ی کاهش وزن غیرفعال است', (tester) async {
    await seed(
      tester,
      NutritionInput(
        sex: Sex.male,
        birthDate: DateTime(DateTime.now().year - 16, 1, 1),
        heightCm: 170,
        weightKg: 75,
        goalWeightKg: 75,
        activityLevel: ActivityLevel.moderate,
        goalType: GoalType.maintain,
        weeklyRateKg: 0.5,
      ),
    );
    await openEdit(tester);

    final lose = tester.widget<RadioListTile<GoalType>>(
      find.byKey(const Key('edit-goal-lose')),
    );
    expect(lose.enabled, isFalse);
    expect(
      find.textContaining('برای زیر ۱۸ سال فقط برنامه‌ی تغذیه‌ی سالم'),
      findsWidgets,
    );
    expect(find.text('تغذیه‌ی سالم'), findsWidgets);
    await disposeApp(tester);
  });
}
