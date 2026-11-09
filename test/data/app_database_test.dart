import 'dart:io';

import 'package:calorie_lens/data/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('نسخه‌ی طرح ۳ است و همه‌ی جدول‌ها ساخته می‌شوند', () async {
    expect(db.schemaVersion, 3);
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'user_profiles',
        'goals',
        'food_logs',
        'weight_logs',
        'water_logs',
        'favorite_foods',
        'custom_meals',
        'pending_scans',
        'app_settings',
      ]),
    );
  });

  test('جدول‌ها در ابتدا خالی‌اند', () async {
    expect(await db.select(db.foodLogs).get(), isEmpty);
    expect(await db.select(db.userProfiles).get(), isEmpty);
  });

  test('تنظیمات کلید-مقدار', () async {
    expect(await db.getSetting('theme_mode'), isNull);
    await db.setSetting('theme_mode', 'dark');
    expect(await db.getSetting('theme_mode'), 'dark');
    await db.setSetting('theme_mode', 'light');
    expect(await db.getSetting('theme_mode'), 'light');
  });

  test('ذخیره‌ی یک FoodLog با enum متنی', () async {
    await db
        .into(db.foodLogs)
        .insert(
          FoodLogsCompanion.insert(
            date: '2026-11-09',
            mealType: MealType.lunch,
            quantity: 1,
            unit: 'gram',
            grams: const Value(100),
            kcal: const Value(null),
            source: LogSource.search,
            createdAt: DateTime.utc(2026, 11, 9),
            customName: const Value('تست'),
          ),
        );
    final row = await db.select(db.foodLogs).getSingle();
    expect(row.mealType, MealType.lunch);
    expect(row.source, LogSource.search);
    // داده‌ی ناقص null می‌ماند، صفر نمی‌شود.
    expect(row.kcal, isNull);
  });

  test('مهاجرت v1 ← v3: داده حفظ و ستون‌ها nullable می‌شوند', () async {
    await db.close();
    // ۱) پایگاه کامل روی دیسک بساز، ۲) جدول food_logs را به طرح دقیق
    // نسخه‌ی ۱ (از sqlite_master نسخه‌ی ۱) برگردان و user_version=1 کن.
    final dir = Directory.systemTemp.createTempSync('cl_mig');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.customSelect('SELECT 1').get();
    await fresh.close();

    var downgraded = false;
    final v1 = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          if (downgraded) return;
          downgraded = true;
          raw.execute('DROP TABLE food_logs');
          // pending_scans هم به طرح نسخه‌ی ۱ برمی‌گردد (مهاجرت تا v3 ادامه دارد).
          raw.execute('DROP TABLE pending_scans');
          raw.execute(
            'CREATE TABLE "pending_scans" ("id" INTEGER NOT NULL PRIMARY KEY '
            'AUTOINCREMENT, "photo_path" TEXT NOT NULL, "created_at" INTEGER '
            'NOT NULL, "status" TEXT NOT NULL)',
          );
          raw.execute(
            'CREATE TABLE "food_logs" ("id" INTEGER NOT NULL PRIMARY KEY '
            'AUTOINCREMENT, "date" TEXT NOT NULL, "meal_type" TEXT NOT NULL, '
            '"food_id" TEXT NULL, "custom_name" TEXT NULL, "quantity" REAL '
            'NOT NULL, "unit" TEXT NOT NULL, "grams" REAL NOT NULL, "kcal" '
            'REAL NOT NULL, "protein" REAL NOT NULL, "carbs" REAL NOT NULL, '
            '"fat" REAL NOT NULL, "source" TEXT NOT NULL, "photo_path" TEXT '
            'NULL, "scan_id" TEXT NULL, "created_at" INTEGER NOT NULL)',
          );
          raw.execute(
            "INSERT INTO food_logs (date, meal_type, food_id, quantity, unit, "
            "grams, kcal, protein, carbs, fat, source, created_at) VALUES "
            "('2026-11-01', 'lunch', 'chelo', 1, 'kafgir', 120, 200, 4, 40, "
            "1, 'search', 0)",
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    db = v1;
    final rows = await db.select(db.foodLogs).get();
    expect(rows.single.kcal, 200);
    expect(rows.single.foodId, 'chelo');
    await db
        .into(db.foodLogs)
        .insert(
          FoodLogsCompanion.insert(
            date: '2026-11-02',
            mealType: MealType.snack,
            quantity: 1,
            unit: 'piece',
            source: LogSource.search,
            createdAt: DateTime.utc(2026),
          ),
        );
    expect((await db.select(db.foodLogs).get()).last.grams, isNull);
  });
}
