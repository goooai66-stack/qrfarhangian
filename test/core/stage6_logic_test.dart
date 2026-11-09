import 'package:calorie_lens/core/nutrition/nutrition_types.dart';
import 'package:calorie_lens/core/nutrition/serving.dart';
import 'package:calorie_lens/core/recognition/food_recognizer.dart';
import 'package:calorie_lens/data/db/app_database.dart' hide MealType;
import 'package:calorie_lens/data/logs/custom_meal_repository.dart';
import 'package:calorie_lens/data/logs/food_log_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('وعده‌ی پیش‌فرض در رمضان', () {
    MealType at(int h) =>
        defaultMealForTime(DateTime(2026, 3, 1, h), ramadan: true);
    expect(at(3), MealType.breakfast); // سحر
    expect(at(18), MealType.dinner); // افطار
    expect(at(12), MealType.snack); // ناهار نیست
  });

  test('meal از پاسخ ثبت صوتی', () {
    final r = RecognitionResult.fromJson({
      'items': [],
      'is_food': true,
      'meal': 'lunch',
    });
    expect(r.meal, MealType.lunch);
    expect(RecognitionResult.fromJson({'is_food': true}).meal, isNull);
    expect(RecognitionResult.fromJson(r.toJson()).meal, MealType.lunch);
  });

  group('غذای ترکیبی و کپی دیروز', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('کپی وعده‌ی دیروز فقط همان وعده', () async {
      final logs = FoodLogRepository(db);
      Future<void> add(String day, MealType m, String id) => logs.add(
        dayKey: day,
        meal: m,
        foodId: id,
        quantity: 1,
        unit: 'gram',
        grams: 100,
        nutrients: const Nutrients(kcal: 100),
      );
      await add('2026-11-08', MealType.lunch, 'chelo');
      await add('2026-11-08', MealType.lunch, 'gheymeh');
      await add('2026-11-08', MealType.dinner, 'doogh');
      final n = await logs.copyMeal(
        fromDay: '2026-11-08',
        toDay: '2026-11-09',
        meal: MealType.lunch,
      );
      expect(n, 2);
      final today = await logs.watchDay('2026-11-09').first;
      expect(today.map((l) => l.foodId), ['chelo', 'gheymeh']);
      expect(today.first.kcal, 100);
      expect(await logs.watchDay('2026-11-08').first, hasLength(3));
    });

    test('ساخت، ثبت و حذف غذای ترکیبی', () async {
      final repo = CustomMealRepository(db);
      final logs = FoodLogRepository(db);
      final id = await repo.create('صبحانه‌ی همیشگی', [
        (foodId: 'nan_barbari', quantity: 1, unit: 'palm'),
        (foodId: 'panir', quantity: 2, unit: 'tablespoon'),
        (foodId: 'not_in_db', quantity: 1, unit: 'gram'),
      ]);
      final m = (await repo.watchAll().first).single;
      expect(CustomMealRepository.itemsOf(m), hasLength(3));
      final n = await repo.logToMeal(
        m,
        foods: loadAppFoods(),
        logs: logs,
        dayKey: '2026-11-09',
        mealType: MealType.breakfast,
      );
      expect(n, 2); // غذای ناشناخته رد شد
      final today = await logs.watchDay('2026-11-09').first;
      expect(today.map((l) => (l.foodId, l.quantity)), [
        ('nan_barbari', 1.0),
        ('panir', 2.0),
      ]);
      await repo.delete(id);
      expect(await repo.watchAll().first, isEmpty);
    });
  });
}
