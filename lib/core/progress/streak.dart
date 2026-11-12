/// زنجیره‌ی روزهای پیاپی 🔥 (بخش ۴-۳). روز «ثبت‌شده» = حداقل یک غذا.
library;

import '../utils/jalali_date.dart';

/// زنجیره‌ی فعلی: روزهای پیاپی تا امروز. اگر امروز هنوز چیزی ثبت نشده،
/// زنجیره‌ی تا دیروز حفظ می‌شود (تا شب فرصت هست).
int currentStreak(Set<String> loggedDays, DateTime today) {
  var day = dateOnly(today);
  if (!loggedDays.contains(dayKey(day))) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var n = 0;
  while (loggedDays.contains(dayKey(day))) {
    n++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return n;
}

/// طولانی‌ترین زنجیره در کل تاریخچه.
int longestStreak(Set<String> loggedDays) {
  final days = loggedDays.map(parseDayKey).toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in days) {
    final consecutive =
        prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d;
    run = consecutive ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}
