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

  /// نسخه‌ی ۱. هر تغییر جدول = افزایش این عدد + یک گام در [migration].
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_food_logs_date ON food_logs (date)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_weight_logs_date ON weight_logs (date)',
      );
    },
    onUpgrade: (m, from, to) async {
      // مهاجرت‌های نسخه‌های بعد اینجا اضافه می‌شوند:
      // if (from < 2) { ... }
    },
  );

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
