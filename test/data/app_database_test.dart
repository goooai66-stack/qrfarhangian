import 'package:calorie_lens/data/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('نسخه‌ی طرح ۱ است و همه‌ی جدول‌ها ساخته می‌شوند', () async {
    expect(db.schemaVersion, 1);
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
            grams: 100,
            kcal: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            source: LogSource.search,
            createdAt: DateTime.utc(2026, 11, 9),
            customName: const Value('تست'),
          ),
        );
    final row = await db.select(db.foodLogs).getSingle();
    expect(row.mealType, MealType.lunch);
    expect(row.source, LogSource.search);
  });
}
