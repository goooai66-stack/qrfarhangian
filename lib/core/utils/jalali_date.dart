/// ابزار تاریخ شمسی (محاسبه و قالب عددی؛ نام‌ها در فایل ترجمه).
///
/// قانون بخش ۲-۴: نمایش شمسی، ذخیره به‌صورت UTC/ISO، هفته از شنبه.
library;

import 'package:shamsi_date/shamsi_date.dart';

import 'persian_digits.dart';

/// اجزای تاریخ شمسی. نام ماه‌ها و روزها در فایل ترجمه‌اند
/// (`lib/l10n/date_names.dart`)، نه اینجا.
({int year, int month, int day}) jalaliParts(DateTime date) {
  final j = Jalali.fromDateTime(date.toLocal());
  return (year: j.year, month: j.month, day: j.day);
}

/// اندیس روز هفته با شروع از شنبه: شنبه=۰ … جمعه=۶.
int weekdayIndexFromSaturday(DateTime date) =>
    (date.weekday + 1) % 7; // DateTime: Monday=1 … Sunday=7, Saturday=6

/// اولین روز (شنبه) هفته‌ای که [date] در آن است (ساعت ۰۰:۰۰ محلی).
DateTime startOfWeek(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: weekdayIndexFromSaturday(d)));
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

/// فقط تاریخ (ساعت ۰۰:۰۰ محلی).
DateTime dateOnly(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// «YYYY-MM-DD» ← DateTime محلی؛ برعکس [dayKey].
DateTime parseDayKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// روز شمسی ماه (۱ تا ۳۱).
int jalaliDay(DateTime date) => Jalali.fromDateTime(date.toLocal()).day;
