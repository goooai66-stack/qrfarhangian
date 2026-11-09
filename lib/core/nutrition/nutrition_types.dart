/// نوع‌های پایه‌ی تغذیه. لایه‌ی داده (Drift) هم از همین‌ها استفاده می‌کند.
library;

enum Sex { male, female }

/// سطح فعالیت و ضریب TDEE (بخش ۶-۲).
enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const ActivityLevel(this.factor);
  final double factor;
}

enum GoalType { lose, maintain, gain }

/// سرعت‌های مجاز تغییر وزن (کیلو در هفته).
const allowedWeeklyRates = <double>[0.25, 0.5, 0.75];

/// وعده‌ها به ترتیب نمایش.
enum MealType { breakfast, lunch, dinner, snack }

/// وعده‌ی پیش‌فرض بر اساس ساعت (بخش ۴-۲).
/// ۴ تا ۱۰:۵۹ صبحانه، ۱۱ تا ۱۵:۵۹ ناهار، ۱۹ تا ۲۲:۵۹ شام، بقیه میان‌وعده.
MealType defaultMealForTime(DateTime t) {
  final h = t.hour;
  if (h >= 4 && h < 11) return MealType.breakfast;
  if (h >= 11 && h < 16) return MealType.lunch;
  if (h >= 19 && h < 23) return MealType.dinner;
  return MealType.snack;
}
