import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    UserProfiles,
    Goals,
    FoodLogs,
    WeightLogs,
    WaterLogs,
    FavoriteFoods,
    CustomMeals,
    PendingScans,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'calorie_lens'));

  /// هر تغییر جدول = افزایش این عدد + یک گام در [migration].
  /// v2: ستون‌های grams/kcal/protein/carbs/fat در food_logs nullable شدند.
  /// v3: ستون‌های meal_type/date/result_json/attempts در pending_scans.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // تغییر nullability در SQLite = بازسازی جدول با حفظ داده.
        await m.alterTable(TableMigration(foodLogs));
        await _createIndexes();
      }
      if (from < 3) {
        await m.addColumn(pendingScans, pendingScans.mealType);
        await m.addColumn(pendingScans, pendingScans.date);
        await m.addColumn(pendingScans, pendingScans.resultJson);
        await m.addColumn(pendingScans, pendingScans.attempts);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_food_logs_date ON food_logs (date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_weight_logs_date ON weight_logs (date)',
    );
  }

  // ---- تنظیمات کلید-مقدار ----

  Future<String?> getSetting(String key) async {
    final row = await (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(appSettings)
          .insertOnConflictUpdate(AppSetting(key: key, value: value));
}
