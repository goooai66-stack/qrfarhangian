/// واحد نمایش وزن (بخش ۴-۷). ذخیره همیشه کیلوگرم است؛ تبدیل فقط هنگام
/// نمایش و ورودی انجام می‌شود (مثل قاعده‌ی ارقام: نمایش فارسی، ذخیره لاتین).
library;

import 'dart:math' as math;

const lbPerKg = 2.20462262185;

enum WeightUnit {
  kg(step: 0.5, fractionDigits: 1),
  lb(step: 1, fractionDigits: 1);

  const WeightUnit({required this.step, required this.fractionDigits});

  /// گام چرخ انتخاب در همین واحد.
  final double step;

  /// گام ریزتر برای ثبت وزن روزانه.
  double get fineStep => this == WeightUnit.kg ? 0.1 : 0.2;

  /// حداکثر رقم اعشار نمایش (صفرهای انتهایی حذف می‌شوند: ۱۵۵ پوند، ۱۵۴٫۳ پوند).
  final int fractionDigits;

  static WeightUnit fromName(String? name) =>
      values.where((u) => u.name == name).firstOrNull ?? kg;

  double fromKg(double kg) => this == WeightUnit.kg ? kg : kg * lbPerKg;

  double toKg(double v) => this == WeightUnit.kg ? v : v / lbPerKg;

  /// مقدارهای چرخ در این واحد، همه داخل [minKg, maxKg]
  /// (پوند: گرد به سمت داخل تا وزن انتخابی از محدوده‌ی مجاز بیرون نزند).
  List<double> wheelValues(double minKg, double maxKg, {double? step}) {
    final st = step ?? this.step;
    final lo = (fromKg(minKg) / st - 1e-9).ceil();
    final hi = (fromKg(maxKg) / st + 1e-9).floor();
    // گرد کردن تا خطای ممیز شناور (مثل ۱۵۴٫۶۰۰۰۰۰۰۱) در برچسب‌ها نیاید.
    return [for (var i = lo; i <= hi; i++) (i * st * 10).round() / 10];
  }

  /// نزدیک‌ترین مقدار چرخ به وزن ذخیره‌شده.
  double nearestOnWheel(List<double> wheel, double kg) {
    final v = fromKg(kg);
    return wheel.reduce((a, b) => (a - v).abs() <= (b - v).abs() ? a : b);
  }

  /// گرد کردن برای نمایش (بدون اعداد بی‌معنی مثل ۱۵۴٫۳۲۴).
  double display(double kg) {
    final f = math.pow(10, fractionDigits);
    return (fromKg(kg) * f).round() / f;
  }
}
