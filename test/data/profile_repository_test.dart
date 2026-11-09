import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProfileRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProfileRepository(db);
  });
  tearDown(() => db.close());

  final input = NutritionInput(
    sex: Sex.female,
    birthDate: DateTime(1996, 1, 1),
    heightCm: 165,
    weightKg: 70,
    goalWeightKg: 62,
    activityLevel: ActivityLevel.light,
    goalType: GoalType.lose,
    weeklyRateKg: 0.5,
  );

  test('ذخیره‌ی آنبوردینگ', () async {
    expect(await repo.hasProfile(), isFalse);
    final plan = calculatePlan(input, today: DateTime(2026, 11, 9));
    await repo.saveOnboarding(input, plan);

    expect(await repo.hasProfile(), isTrue);
    final p = (await repo.getProfile())!;
    expect(p.sex, Sex.female);
    expect(p.startWeightKg, 70);
    expect(p.goalType, GoalType.lose);
    final g = (await repo.watchActiveGoal().first)!;
    expect(g.kcal, 1403);
    expect(await repo.watchCurrentWeight().first, 70);
  });

  test('هدف غیرمجاز با هدف اجراشده ذخیره می‌شود', () async {
    final minor = NutritionInput(
      sex: Sex.female,
      birthDate: DateTime(2011, 1, 1),
      heightCm: 160,
      weightKg: 60,
      goalWeightKg: 55,
      activityLevel: ActivityLevel.light,
      goalType: GoalType.lose,
      weeklyRateKg: 0.5,
    );
    await repo.saveOnboarding(
      minor,
      calculatePlan(minor, today: DateTime(2026, 11, 9)),
    );
    expect((await repo.getProfile())!.goalType, GoalType.maintain);
  });

  test('ویرایش: هدف جدید در تاریخچه و وزن شروع حفظ می‌شود', () async {
    await repo.saveOnboarding(input, calculatePlan(input));
    final edited = NutritionInput(
      sex: Sex.female,
      birthDate: input.birthDate,
      heightCm: 165,
      weightKg: 68,
      goalWeightKg: 62,
      activityLevel: ActivityLevel.moderate,
      goalType: GoalType.lose,
      weeklyRateKg: 0.25,
    );
    final plan = calculatePlan(edited);
    await repo.updateProfile(edited, plan);

    final profiles = await db.select(db.userProfiles).get();
    expect(profiles, hasLength(1));
    expect(profiles.single.startWeightKg, 70);
    expect(profiles.single.activityLevel, ActivityLevel.moderate);
    expect(await db.select(db.goals).get(), hasLength(2));
    expect((await repo.watchActiveGoal().first)!.kcal, plan.targetKcal);
    // همان روز: یک ثبت وزن، با مقدار جدید.
    expect(await db.select(db.weightLogs).get(), hasLength(1));
    expect(await repo.watchCurrentWeight().first, 68);
  });
}
