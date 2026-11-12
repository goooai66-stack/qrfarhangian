import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../foods/food_repository.dart';
import 'food_log_repository.dart';

/// یک قلم از «غذای ترکیبی من».
typedef CustomMealItem = ({String foodId, double quantity, String unit});

/// «غذای ترکیبی من» (مثلاً «صبحانه‌ی همیشگی‌ام») و کپی وعده‌ی دیروز.
class CustomMealRepository {
  CustomMealRepository(this._db);
  final AppDatabase _db;

  static List<CustomMealItem> itemsOf(CustomMeal m) {
    try {
      return [
        for (final e in jsonDecode(m.itemsJson) as List)
          (
            foodId: (e as Map)['foodId'] as String,
            quantity: (e['quantity'] as num).toDouble(),
            unit: e['unit'] as String,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Stream<List<CustomMeal>> watchAll() => (_db.select(
    _db.customMeals,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<int> create(String name, List<CustomMealItem> items) => _db
      .into(_db.customMeals)
      .insert(
        CustomMealsCompanion.insert(
          name: name.trim(),
          itemsJson: Value(
            jsonEncode([
              for (final i in items)
                {'foodId': i.foodId, 'quantity': i.quantity, 'unit': i.unit},
            ]),
          ),
        ),
      );

  /// ذخیره‌ی ثبت‌های یک وعده به‌عنوان غذای ترکیبی (فقط آیتم‌هایی که غذایشان معلوم است).
  Future<int> createFromLogs(String name, List<FoodLog> logs) => create(name, [
    for (final l in logs)
      if (l.foodId != null)
        (foodId: l.foodId!, quantity: l.quantity, unit: l.unit),
  ]);

  Future<void> delete(int id) =>
      (_db.delete(_db.customMeals)..where((t) => t.id.equals(id))).go();

  /// ثبت همه‌ی اقلام در وعده؛ ارزش غذایی با داده‌ی فعلی پایگاه غذا محاسبه می‌شود.
  Future<int> logToMeal(
    CustomMeal meal, {
    required FoodRepository foods,
    required FoodLogRepository logs,
    required String dayKey,
    required MealType mealType,
  }) async {
    var n = 0;
    await _db.transaction(() async {
      for (final i in itemsOf(meal)) {
        final food = foods.byId(i.foodId);
        if (food == null) continue;
        final s = food.serving(i.unit, i.quantity);
        await logs.add(
          dayKey: dayKey,
          meal: mealType,
          foodId: food.id,
          quantity: i.quantity,
          unit: i.unit,
          grams: s.grams,
          nutrients: s.nutrients,
        );
        n++;
      }
    });
    return n;
  }
}
