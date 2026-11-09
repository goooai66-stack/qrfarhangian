import 'package:calorie_lens/core/nutrition/serving.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/logs/food_log_repository.dart';
import 'package:calorie_lens/data/progress/progress_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProgressRepository repo;
  late FoodLogRepository logs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProgressRepository(db);
    logs = FoodLogRepository(db);
  });
  tearDown(() => db.close());

  Future<void> log(String day, Nutrients n) => logs.add(
    dayKey: day,
    meal: MealType.lunch,
    foodId: 'chelo',
    quantity: 1,
    unit: 'gram',
    grams: 100,
    nutrients: n,
  );

  test('وزن: یکی در روز و مرتب بر اساس تاریخ', () async {
    await repo.setWeight(DateTime(2026, 11, 9), 70);
    await repo.setWeight(DateTime(2026, 11, 2), 71);
    await repo.setWeight(DateTime(2026, 11, 9), 69.5);
    final w = await repo.watchWeights().first;
    expect(w.map((e) => (e.date, e.weightKg)), [
      ('2026-11-02', 71.0),
      ('2026-11-09', 69.5),
    ]);
    await repo.deleteWeight(w.first.id);
    expect(await repo.watchWeights().first, hasLength(1));
  });

  test('جمع روزانه در بازه و روزهای ثبت‌شده', () async {
    const n = Nutrients(kcal: 500, protein: 20, carbs: 60, fat: 15);
    await log('2026-11-01', n);
    await log('2026-11-08', n);
    await log('2026-11-08', const Nutrients());
    await log('2026-11-09', n);
    final totals = await repo
        .watchDailyTotals(DateTime(2026, 11, 3), DateTime(2026, 11, 9))
        .first;
    expect(totals.keys.toSet(), {'2026-11-08', '2026-11-09'});
    expect(totals['2026-11-08']!.kcal, 500);
    expect(totals['2026-11-08']!.incompleteCount, 1);
    expect(await repo.watchLoggedDays().first, {
      '2026-11-01',
      '2026-11-08',
      '2026-11-09',
    });
  });

  test('بیشترین لیوان آب', () async {
    expect(await repo.watchMaxWaterGlasses().first, 0);
    await logs.setWater('2026-11-08', 5);
    await logs.setWater('2026-11-09', 8);
    expect(await repo.watchMaxWaterGlasses().first, 8);
  });
}
