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
