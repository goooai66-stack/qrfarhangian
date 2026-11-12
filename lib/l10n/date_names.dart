import '../core/utils/jalali_date.dart';
import '../core/utils/persian_digits.dart';
import 'app_localizations.dart';

/// نام ماه‌ها و روزهای شمسی و قالب تاریخ، از فایل ترجمه (نه کد).
extension JalaliDateNames on AppLocalizations {
  List<String> get jalaliMonths => [
    month1, month2, month3, month4, month5, month6, //
    month7, month8, month9, month10, month11, month12,
  ];

  /// اندیس ۰ = شنبه.
  List<String> get weekdays => [
    weekdaySat, weekdaySun, weekdayMon, weekdayTue, //
    weekdayWed, weekdayThu, weekdayFri,
  ];

  List<String> get weekdaysShort => [
    weekdayShortSat, weekdayShortSun, weekdayShortMon, weekdayShortTue, //
    weekdayShortWed, weekdayShortThu, weekdayShortFri,
  ];

  /// نام ماه شمسی (۱ تا ۱۲).
  String monthName(int month) => jalaliMonths[month - 1];

  String weekdayName(DateTime date) =>
      weekdays[weekdayIndexFromSaturday(date.toLocal())];

  String weekdayShort(DateTime date) =>
      weekdaysShort[weekdayIndexFromSaturday(date.toLocal())];

  /// «۱۸ آبان ۱۴۰۵»
  String formatDateLong(DateTime date) {
    final j = jalaliParts(date);
    return dateLong(
      toPersianDigits('${j.day}'),
      monthName(j.month),
      toPersianDigits('${j.year}'),
    );
  }

  /// «دوشنبه ۱۸ آبان ۱۴۰۵»
  String formatDateWithWeekday(DateTime date) =>
      dateWithWeekday(weekdayName(date), formatDateLong(date));
}
