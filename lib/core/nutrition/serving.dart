/// محاسبه‌ی ارزش غذایی یک وعده از داده‌ی «در ۱۰۰ گرم».
///
/// اصل: هر مقداری که داده‌اش نیست null می‌ماند و هرگز با صفر یا حدس پر
/// نمی‌شود (بخش ۲-۶).
library;

class Nutrients {
  const Nutrients({this.kcal, this.protein, this.carbs, this.fat});

  static const empty = Nutrients(kcal: 0, protein: 0, carbs: 0, fat: 0);

  final double? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;

  /// هر چهار مقدار موجود است.
  bool get isComplete =>
      kcal != null && protein != null && carbs != null && fat != null;

  Nutrients scaled(double factor) => Nutrients(
    kcal: kcal == null ? null : kcal! * factor,
    protein: protein == null ? null : protein! * factor,
    carbs: carbs == null ? null : carbs! * factor,
    fat: fat == null ? null : fat! * factor,
  );

  @override
  bool operator ==(Object other) =>
      other is Nutrients &&
      other.kcal == kcal &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat;

  @override
  int get hashCode => Object.hash(kcal, protein, carbs, fat);

  @override
  String toString() => 'Nutrients($kcal, $protein, $carbs, $fat)';
}

/// گرم کل = مقدار × وزن هر واحد. اگر وزن واحد معلوم نیست، null.
double? servingGrams({required double quantity, required double? unitGrams}) =>
    unitGrams == null ? null : quantity * unitGrams;

/// ارزش غذایی وعده. اگر [grams] نامعلوم باشد همه null می‌شوند.
Nutrients servingNutrients(Nutrients per100g, double? grams) =>
    grams == null ? const Nutrients() : per100g.scaled(grams / 100);

/// جمع روزانه: فقط مقادیر معلوم جمع می‌شوند؛ [incompleteCount] تعداد
/// آیتم‌هایی است که کالری‌شان معلوم نیست.
class DayTotals {
  const DayTotals({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.incompleteCount,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final int incompleteCount;

  static DayTotals sum(Iterable<Nutrients> items) {
    var k = 0.0, p = 0.0, c = 0.0, f = 0.0;
    var missing = 0;
    for (final n in items) {
      k += n.kcal ?? 0;
      p += n.protein ?? 0;
      c += n.carbs ?? 0;
      f += n.fat ?? 0;
      if (!n.isComplete) missing++;
    }
    return DayTotals(
      kcal: k,
      protein: p,
      carbs: c,
      fat: f,
      incompleteCount: missing,
    );
  }
}
