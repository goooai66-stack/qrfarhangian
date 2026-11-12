import 'package:drift/drift.dart';

import '../../core/nutrition/serving.dart';
import '../db/app_database.dart';

/// ثبت غذا، علاقه‌مندی‌ها، غذاهای اخیر/پرتکرار و آب. همه محلی و آفلاین.
class FoodLogRepository {
  FoodLogRepository(this._db);

  final AppDatabase _db;

  // ---- ثبت‌های روز ----

  /// ثبت‌های یک روز (کلید «YYYY-MM-DD» محلی)، به ترتیب زمان ثبت.
  Stream<List<FoodLog>> watchDay(String dayKey) =>
      (_db.select(_db.foodLogs)
            ..where((t) => t.date.equals(dayKey))
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch();

  Future<FoodLog?> byId(int id) => (_db.select(
    _db.foodLogs,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// [foodId] یا [customName] (برای غذای پیدانشده در اسکن) لازم است.
  Future<int> add({
    required String dayKey,
    required MealType meal,
    String? foodId,
    String? customName,
    required double quantity,
    required String unit,
    required double? grams,
    required Nutrients nutrients,
    LogSource source = LogSource.search,
    String? photoPath,
    String? scanId,
    DateTime? now,
  }) {
    assert(foodId != null || customName != null);
    return _db
        .into(_db.foodLogs)
        .insert(
          FoodLogsCompanion.insert(
            date: dayKey,
            mealType: meal,
            foodId: Value(foodId),
            customName: Value(customName),
            quantity: quantity,
            unit: unit,
            grams: Value(grams),
            kcal: Value(nutrients.kcal),
            protein: Value(nutrients.protein),
            carbs: Value(nutrients.carbs),
            fat: Value(nutrients.fat),
            source: source,
            photoPath: Value(photoPath),
            scanId: Value(scanId),
            createdAt: now ?? DateTime.now(),
          ),
        );
  }

  /// ویرایش مقدار/واحد/وعده؛ ارزش غذایی دوباره snapshot می‌شود.
  Future<void> updateServing(
    int id, {
    required MealType meal,
    required double quantity,
    required String unit,
    required double? grams,
    required Nutrients nutrients,
  }) => (_db.update(_db.foodLogs)..where((t) => t.id.equals(id))).write(
    FoodLogsCompanion(
      mealType: Value(meal),
      quantity: Value(quantity),
      unit: Value(unit),
      grams: Value(grams),
      kcal: Value(nutrients.kcal),
      protein: Value(nutrients.protein),
      carbs: Value(nutrients.carbs),
      fat: Value(nutrients.fat),
    ),
  );

  /// کپی ثبت‌های یک وعده از روزی به روز دیگر (همان مقادیر ثبت‌شده).
  Future<int> copyMeal({
    required String fromDay,
    required String toDay,
    required MealType meal,
  }) => _db.transaction(() async {
    final rows =
        await (_db.select(_db.foodLogs)
              ..where(
                (t) => t.date.equals(fromDay) & t.mealType.equalsValue(meal),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    final now = DateTime.now();
    for (final r in rows) {
      await _db
          .into(_db.foodLogs)
          .insert(
            r
                .toCompanion(false)
                .copyWith(
                  id: const Value.absent(),
                  date: Value(toDay),
                  createdAt: Value(now),
                  scanId: const Value(null),
                ),
          );
    }
    return rows.length;
  });

  Future<void> delete(int id) =>
      (_db.delete(_db.foodLogs)..where((t) => t.id.equals(id))).go();

  // ---- اخیر و پرتکرار ----

  /// تعداد دفعات ثبت هر غذا (برای رتبه‌بندی جستجو و «پرتکرار»).
  Stream<Map<String, int>> watchFrequency() {
    final count = _db.foodLogs.id.count();
    final q = _db.selectOnly(_db.foodLogs)
      ..addColumns([_db.foodLogs.foodId, count])
      ..where(_db.foodLogs.foodId.isNotNull())
      ..groupBy([_db.foodLogs.foodId]);
    return q.watch().map(
      (rows) => {
        for (final r in rows) r.read(_db.foodLogs.foodId)!: r.read(count)!,
      },
    );
  }

  /// آخرین غذاهای ثبت‌شده (بدون تکرار)، جدیدترین اول.
  Stream<List<String>> watchRecentFoodIds({int limit = 10}) {
    final last = _db.foodLogs.createdAt.max();
    final q = _db.selectOnly(_db.foodLogs)
      ..addColumns([_db.foodLogs.foodId, last])
      ..where(_db.foodLogs.foodId.isNotNull())
      ..groupBy([_db.foodLogs.foodId])
      ..orderBy([OrderingTerm.desc(last)])
      ..limit(limit);
    return q.watch().map(
      (rows) => [for (final r in rows) r.read(_db.foodLogs.foodId)!],
    );
  }

  // ---- علاقه‌مندی‌ها ----

  Stream<Set<String>> watchFavorites() => _db
      .select(_db.favoriteFoods)
      .watch()
      .map((rows) => {for (final r in rows) r.foodId});

  Future<void> setFavorite(String foodId, bool favorite) async {
    if (favorite) {
      await _db
          .into(_db.favoriteFoods)
          .insertOnConflictUpdate(FavoriteFood(foodId: foodId));
    } else {
      await (_db.delete(
        _db.favoriteFoods,
      )..where((t) => t.foodId.equals(foodId))).go();
    }
  }

  // ---- آب ----

  Stream<int> watchWater(String dayKey) =>
      (_db.select(_db.waterLogs)..where((t) => t.date.equals(dayKey)))
          .watchSingleOrNull()
          .map((r) => r?.glasses ?? 0);

  Future<void> setWater(String dayKey, int glasses) => _db
      .into(_db.waterLogs)
      .insert(
        WaterLogsCompanion.insert(
          date: dayKey,
          glasses: Value(glasses < 0 ? 0 : glasses),
        ),
        onConflict: DoUpdate(
          (_) => WaterLogsCompanion(glasses: Value(glasses < 0 ? 0 : glasses)),
          target: [_db.waterLogs.date],
        ),
      );
}
