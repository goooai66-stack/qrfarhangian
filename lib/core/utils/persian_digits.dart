/// تبدیل ارقام بین لاتین، فارسی و عربی.
///
/// قانون بخش ۲-۳: در نمایش ارقام فارسی، در ذخیره و محاسبه ارقام لاتین.
library;

const _latin = '0123456789';
const _persian = '۰۱۲۳۴۵۶۷۸۹';
const _arabic = '٠١٢٣٤٥٦٧٨٩';

/// ارقام لاتین (و عربی) را به ارقام فارسی تبدیل می‌کند. فقط برای نمایش.
String toPersianDigits(String input) {
  final buf = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    var i = _latin.indexOf(ch);
    if (i < 0) i = _arabic.indexOf(ch);
    buf.write(i >= 0 ? _persian[i] : ch);
  }
  return buf.toString();
}

/// ارقام فارسی و عربی را به لاتین تبدیل می‌کند. برای ورودی کاربر قبل از ذخیره/محاسبه.
String toLatinDigits(String input) {
  final buf = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    var i = _persian.indexOf(ch);
    if (i < 0) i = _arabic.indexOf(ch);
    buf.write(i >= 0 ? _latin[i] : ch);
  }
  return buf.toString();
}

/// عدد را برای نمایش فارسی قالب‌بندی می‌کند.
///
/// [fractionDigits]: تعداد رقم اعشار (صفرهای انتهایی حذف می‌شوند).
/// [grouping]: جداکننده‌ی هزارگان «٬».
/// جداکننده‌ی اعشار فارسی «٫» است.
String formatPersianNumber(
  num value, {
  int fractionDigits = 0,
  bool grouping = true,
}) {
  final negative = value < 0;
  var s = value.abs().toStringAsFixed(fractionDigits);
  String intPart = s;
  String frac = '';
  final dot = s.indexOf('.');
  if (dot >= 0) {
    intPart = s.substring(0, dot);
    frac = s.substring(dot + 1).replaceFirst(RegExp(r'0+$'), '');
  }
  if (grouping && intPart.length > 3) {
    final b = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) b.write('٬');
      b.write(intPart[i]);
    }
    intPart = b.toString();
  }
  final out = frac.isEmpty ? intPart : '$intPart٫$frac';
  // علامت منفی با U+2212 تا در متن RTL درست نمایش داده شود.
  return toPersianDigits(negative && value != 0 ? '−$out' : out);
}

/// ورودی عددی کاربر (با ارقام فارسی/عربی و جداکننده‌ی «٫» یا «,») را می‌خواند.
num? parsePersianNumber(String input) {
  final s = toLatinDigits(input.trim())
      .replaceAll('٬', '')
      .replaceAll('٫', '.')
      .replaceAll('،', '.')
      .replaceAll('−', '-');
  return num.tryParse(s);
}
