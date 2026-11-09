import 'package:calorie_lens/core/nutrition/nutrition_types.dart';
import 'package:calorie_lens/core/nutrition/serving.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const per100 = Nutrients(kcal: 130, protein: 2.5, carbs: 28, fat: 0.5);

  test('محاسبه از ۱۰۰ گرم', () {
    final n = servingNutrients(per100, 90);
    expect(n.kcal, closeTo(117, 1e-9));
    expect(n.protein, closeTo(2.25, 1e-9));
    expect(n.carbs, closeTo(25.2, 1e-9));
    expect(n.fat, closeTo(0.45, 1e-9));
  });

  test('گرم = مقدار × وزن واحد', () {
    expect(servingGrams(quantity: 1.5, unitGrams: 60), 90);
    expect(servingGrams(quantity: 2, unitGrams: null), isNull);
  });

  test('وزن واحد نامعلوم ← همه‌چیز null (نه صفر)', () {
    final n = servingNutrients(per100, null);
    expect(n.kcal, isNull);
    expect(n.isComplete, isFalse);
  });

  test('داده‌ی ناقص غذا ← null می‌ماند', () {
    final n = servingNutrients(const Nutrients(kcal: 100), 50);
    expect(n.kcal, 50);
    expect(n.protein, isNull);
    expect(n.isComplete, isFalse);
  });

  test('جمع روز: فقط مقادیر معلوم + شمارش ناقص‌ها', () {
    final t = DayTotals.sum(const [
      Nutrients(kcal: 200, protein: 10, carbs: 20, fat: 5),
      Nutrients(),
      Nutrients(kcal: 100, protein: 5, carbs: 10, fat: 2),
    ]);
    expect(t.kcal, 300);
    expect(t.protein, 15);
    expect(t.incompleteCount, 1);
  });

  group('وعده‌ی پیش‌فرض بر اساس ساعت', () {
    MealType at(int h, [int m = 0]) =>
        defaultMealForTime(DateTime(2026, 11, 9, h, m));
    test('صبحانه', () {
      expect(at(4), MealType.breakfast);
      expect(at(10, 59), MealType.breakfast);
    });
    test('ناهار', () {
      expect(at(11), MealType.lunch);
      expect(at(15, 59), MealType.lunch);
    });
    test('شام', () {
      expect(at(19), MealType.dinner);
      expect(at(22, 59), MealType.dinner);
    });
    test('میان‌وعده', () {
      expect(at(16), MealType.snack);
      expect(at(23), MealType.snack);
      expect(at(2), MealType.snack);
    });
  });
}
