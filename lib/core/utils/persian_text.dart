/// نرمال‌سازی متن فارسی برای جستجو و مقایسه.
///
/// «ي/ى» ← «ی»، «ك» ← «ک»، «ة» ← «ه»، «أ/إ/آ» ← «ا»، «ؤ» ← «و»،
/// حذف اعراب و تطویل، نیم‌فاصله و فاصله‌های تکراری ← یک فاصله،
/// ارقام ← لاتین، حروف لاتین ← کوچک.
library;

import 'persian_digits.dart';

const _charMap = <String, String>{
  'ي': 'ی', // ي عربی
  'ى': 'ی', // الف مقصوره
  'ك': 'ک', // ك عربی
  'ة': 'ه',
  'ۀ': 'ه',
  'أ': 'ا',
  'إ': 'ا',
  'آ': 'ا',
  'ٱ': 'ا',
  'ؤ': 'و',
};

// اعراب عربی (U+064B..U+065F)، الف خنجری (U+0670) و تطویل (U+0640).
final _diacritics = RegExp('[ً-ٰٟـ]');

// نیم‌فاصله (ZWNJ)، ZWJ، فاصله‌ی بدون شکست و سایر فاصله‌های نامرئی.
final _spaces = RegExp('[‌‍ ​  \\s]+');

/// متن را برای جستجو نرمال می‌کند. نتیجه فقط برای مقایسه است، نه نمایش.
String normalizePersian(String input) {
  final buf = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_charMap[ch] ?? ch);
  }
  var s = buf.toString().replaceAll(_diacritics, '');
  s = toLatinDigits(s).toLowerCase();
  s = s.replaceAll(_spaces, ' ').trim();
  return s;
}

/// نسخه‌ی بدون هیچ فاصله؛ تا «قورمه‌سبزی»، «قورمه سبزی» و «قورمهسبزی» یکی شوند.
String normalizePersianCompact(String input) =>
    normalizePersian(input).replaceAll(' ', '');
