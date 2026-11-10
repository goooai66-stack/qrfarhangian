import 'package:calorie_lens/core/units/weight_unit.dart';
import 'package:calorie_lens/features/profile/profile_labels.dart';
import 'package:calorie_lens/l10n/app_localizations_fa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const kg = WeightUnit.kg, lb = WeightUnit.lb;

  test('تبدیل رفت‌وبرگشت', () {
    expect(lb.fromKg(1), closeTo(2.2046, 1e-4));
    expect(lb.toKg(lb.fromKg(73.4)), closeTo(73.4, 1e-9));
    expect(kg.fromKg(70), 70);
    expect(kg.toKg(70), 70);
  });

  test('نام ذخیره‌شده؛ مقدار نامعتبر ← کیلوگرم', () {
    expect(WeightUnit.fromName('lb'), lb);
    expect(WeightUnit.fromName(null), kg);
    expect(WeightUnit.fromName('stone'), kg);
  });

  test('چرخ کیلوگرم همان گام‌های قبلی است', () {
    final w = kg.wheelValues(30, 250);
    expect(w.first, 30);
    expect(w.last, 250);
    expect(w[1] - w[0], 0.5);
  });

  test('چرخ پوند داخل محدوده‌ی مجاز کیلوگرمی می‌ماند', () {
    final w = lb.wheelValues(30, 250);
    expect(w.first, 67); // ۳۰ کیلو = ۶۶٫۱ پوند ← رو به داخل
    expect(w.last, 551); // ۲۵۰ کیلو = ۵۵۱٫۲ پوند
    for (final v in [w.first, w.last]) {
      final k = lb.toKg(v);
      expect(k >= 30 && k <= 250, isTrue);
    }
    // گام ریز بدون خطای ممیز شناور
    final fine = lb.wheelValues(70, 71, step: lb.fineStep);
    expect(fine.every((v) => (v * 10).round() / 10 == v), isTrue);
  });

  test('نزدیک‌ترین مقدار چرخ و گرد کردن نمایش', () {
    final w = lb.wheelValues(30, 250);
    expect(lb.nearestOnWheel(w, 70), 154);
    expect(lb.display(70), 154.3);
    expect(kg.display(69.94), 69.9);
  });

  test('برچسب‌های فارسی', () {
    final t = AppLocalizationsFa();
    expect(t.weight(70, kg), '۷۰ کیلوگرم');
    expect(t.weight(70.5, kg), '۷۰٫۵ کیلوگرم');
    expect(t.weight(70, lb), '۱۵۴٫۳ پوند');
    expect(t.rate(0.5, kg), '۰٫۵ کیلو در هفته');
    expect(t.rate(0.5, lb), '۱٫۱ پوند در هفته');
  });
}
