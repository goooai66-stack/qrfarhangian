import 'package:calorie_lens/core/nutrition/serving.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/logs/food_log_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FoodLogRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FoodLogRepository(db);
  });
  tearDown(() => db.close());

  Future<int> add(String day, String food, {DateTime? at, Nutrients? n}) =>
      repo.add(
        dayKey: day,
        meal: MealType.lunch,
        foodId: food,
        quantity: 1,
        unit: 'piece',
        grams: null,
        nutrients: n ?? const Nutrients(),
        now: at,
      );

  test('ثبت، خواندن روز، ویرایش و حذف', () async {
    final id = await add('2026-11-09', 'chelo');
    await add('2026-11-08', 'doogh');
    final today = await repo.watchDay('2026-11-09').first;
    expect(today.single.foodId, 'chelo');
    expect(today.single.kcal, isNull);

    await repo.updateServing(
      id,
      meal: MealType.dinner,
      quantity: 2,
      unit: 'gram',
      grams: 200,
      nutrients: const Nutrients(kcal: 260, protein: 5, carbs: 56, fat: 1),
    );
    final edited = (await repo.byId(id))!;
    expect(edited.mealType, MealType.dinner);
    expect(edited.kcal, 260);

    await repo.delete(id);
    expect(await repo.watchDay('2026-11-09').first, isEmpty);
    expect(await repo.watchDay('2026-11-08').first, hasLength(1));
  });

  test('پرتکرار و اخیر', () async {
    await add('2026-11-07', 'chelo', at: DateTime(2026, 11, 7));
    await add('2026-11-08', 'chelo', at: DateTime(2026, 11, 8));
    await add('2026-11-08', 'doogh', at: DateTime(2026, 11, 8, 12));
    await add('2026-11-09', 'panir', at: DateTime(2026, 11, 9));
    expect(await repo.watchFrequency().first, {
      'chelo': 2,
      'doogh': 1,
      'panir': 1,
    });
    expect(await repo.watchRecentFoodIds().first, ['panir', 'doogh', 'chelo']);
  });

  test('علاقه‌مندی‌ها', () async {
    await repo.setFavorite('chelo', true);
    await repo.setFavorite('chelo', true);
    await repo.setFavorite('doogh', true);
    expect(await repo.watchFavorites().first, {'chelo', 'doogh'});
    await repo.setFavorite('chelo', false);
    expect(await repo.watchFavorites().first, {'doogh'});
  });

  test('آب: یک رکورد در روز، منفی نمی‌شود', () async {
    expect(await repo.watchWater('2026-11-09').first, 0);
    await repo.setWater('2026-11-09', 3);
    await repo.setWater('2026-11-09', 4);
    expect(await repo.watchWater('2026-11-09').first, 4);
    await repo.setWater('2026-11-09', -1);
    expect(await repo.watchWater('2026-11-09').first, 0);
    expect(await db.select(db.waterLogs).get(), hasLength(1));
  });
}
