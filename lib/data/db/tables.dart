// جدول‌های محلی طبق بخش ۱۰-۳ سند.
//
// قرارداد: همه‌ی زمان‌ها با DateTime ذخیره می‌شوند (Drift پیش‌فرض: ثانیه‌ی
// یونیکس = مستقل از منطقه‌ی زمانی). فیلد `date` در لاگ‌های روزانه رشته‌ی
// «YYYY-MM-DD» بر اساس روز محلی کاربر است (jalali_date.dayKey).
import 'package:drift/drift.dart';

/// enumها به‌صورت متن ذخیره می‌شوند تا تغییر ترتیبشان داده را خراب نکند.
enum Sex { male, female }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum GoalType { lose, maintain, gain }

enum MealType { breakfast, lunch, dinner, snack }

enum LogSource { photo, search, voice, text }

enum PendingScanStatus { queued, processing, failed, done }

class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sex => textEnum<Sex>()();
  DateTimeColumn get birthDate => dateTime()();
  RealColumn get heightCm => real()();
  RealColumn get startWeightKg => real()();
  RealColumn get goalWeightKg => real()();
  TextColumn get activityLevel => textEnum<ActivityLevel>()();
  TextColumn get goalType => textEnum<GoalType>()();
  RealColumn get weeklyRateKg => real()();
  BoolColumn get isPregnant => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

/// تاریخچه‌ی هدف؛ هدف فعال = آخرین رکورد با validFrom <= امروز.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get kcal => integer()();
  RealColumn get proteinG => real()();
  RealColumn get carbsG => real()();
  RealColumn get fatG => real()();
  DateTimeColumn get validFrom => dateTime()();
}

/// مقادیر تغذیه‌ای در لحظه‌ی ثبت snapshot می‌شوند.
class FoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()(); // YYYY-MM-DD محلی
  TextColumn get mealType => textEnum<MealType>()();
  TextColumn get foodId => text().nullable()();
  TextColumn get customName => text().nullable()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  RealColumn get grams => real()();
  RealColumn get kcal => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  TextColumn get source => textEnum<LogSource>()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get scanId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class WeightLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  RealColumn get weightKg => real()();
}

class WaterLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().unique()();
  IntColumn get glasses => integer().withDefault(const Constant(0))();
}

class FavoriteFoods extends Table {
  TextColumn get foodId => text()();

  @override
  Set<Column<Object>> get primaryKey => {foodId};
}

class CustomMeals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// فهرست آیتم‌ها به‌صورت JSON: [{foodId, quantity, unit}]
  TextColumn get itemsJson => text().withDefault(const Constant('[]'))();
}

/// صف اسکن آفلاین.
class PendingScans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get photoPath => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get status => textEnum<PendingScanStatus>()();
}

/// تنظیمات کلید-مقدار.
@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
