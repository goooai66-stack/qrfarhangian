/// ابزار تاریخ شمسی.
///
/// قانون بخش ۲-۴: نمایش شمسی، ذخیره به‌صورت UTC/ISO، هفته از شنبه.
library;

import 'package:shamsi_date/shamsi_date.dart';

import 'persian_digits.dart';

const _monthNames = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', //
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

/// نام روزهای هفته؛ اندیس ۰ = شنبه.
const persianWeekDays = [
  'شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', //
];

/// نام ماه شمسی (۱ تا ۱۲).
String jalaliMonthName(int month) => _monthNames[month - 1];

/// اندیس روز هفته با شروع از شنبه: شنبه=۰ … جمعه=۶.
int weekdayIndexFromSaturday(DateTime date) =>
    (date.weekday + 1) % 7; // DateTime: Monday=1 … Sunday=7, Saturday=6

/// اولین روز (شنبه) هفته‌ای که [date] در آن است (ساعت ۰۰:۰۰ محلی).
DateTime startOfWeek(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: weekdayIndexFromSaturday(d)));
}

/// «۱۸ آبان ۱۴۰۵»
String formatJalaliLong(DateTime date) {
  final j = Jalali.fromDateTime(date.toLocal());
  return toPersianDigits('${j.day} ${jalaliMonthName(j.month)} ${j.year}');
}

/// «یکشنبه ۱۸ آبان ۱۴۰۵»
String formatJalaliWithWeekday(DateTime date) {
  final local = date.toLocal();
  return '${persianWeekDays[weekdayIndexFromSaturday(local)]} '
      '${formatJalaliLong(local)}';
}

/// «۱۴۰۵/۰۸/۱۸»
String formatJalaliShort(DateTime date) {
  final j = Jalali.fromDateTime(date.toLocal());
  String two(int n) => n.toString().padLeft(2, '0');
  return toPersianDigits('${j.year}/${two(j.month)}/${two(j.day)}');
}

/// تاریخ شمسی ← DateTime محلی (ساعت ۰۰:۰۰).
DateTime jalaliToDateTime(int year, int month, int day) =>
    Jalali(year, month, day).toDateTime();

/// قالب ذخیره‌سازی: ISO 8601 به UTC.
String toStorageIso(DateTime date) => date.toUtc().toIso8601String();

/// کلید روز برای ذخیره‌ی رکوردهای روزانه، بر اساس روز محلی کاربر: «2026-11-09».
String dayKey(DateTime date) {
  final l = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year.toString().padLeft(4, '0')}-${two(l.month)}-${two(l.day)}';
}
