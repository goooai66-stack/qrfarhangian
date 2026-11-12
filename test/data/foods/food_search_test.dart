import 'dart:io';

import 'package:calorie_lens/core/nutrition/serving.dart';
import 'package:calorie_lens/data/foods/food.dart';
import 'package:calorie_lens/data/foods/food_repository.dart';
import 'package:calorie_lens/data/foods/food_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = FoodRepository.fromJsonString(
    File(FoodRepository.assetPath).readAsStringSync(),
  );
  String? first(String q, [Map<String, int> f = const {}]) =>
      repo.search(q, frequency: f).firstOrNull?.id;

  group('فایل foods.json', () {
    test('ساختار معتبر', () {
      expect(repo.foods, isNotEmpty);
      for (final f in repo.foods) {
        expect(f.units, isNotEmpty, reason: f.id);
        expect(
          f.units.map((u) => u.unit),
          contains(f.defaultUnit),
          reason: '${f.id}: default_unit در units نیست',
        );
        final gram = f.units.where((u) => u.unit == 'gram');
        if (gram.isNotEmpty) expect(gram.single.grams, 1, reason: f.id);
      }
    });
    test('پایگاه واقعی: همه عدد دارند و کالری با درشت‌مغذی‌ها می‌خواند', () {
      expect(repo.foods.length, greaterThanOrEqualTo(150));
      for (final f in repo.foods) {
        expect(f.hasNutrition, isTrue, reason: f.id);
        final n = f.per100g;
        final macro = 4 * n.protein! + 4 * n.carbs! + 9 * n.fat!;
        expect(
          (macro - n.kcal!).abs(),
          lessThanOrEqualTo(n.kcal! * 0.2 < 25 ? 25 : n.kcal! * 0.2),
          reason: '${f.id}: کالری با درشت‌مغذی‌ها نمی‌خواند',
        );
        for (final u in f.units) {
          expect(u.grams, isNotNull, reason: '${f.id}/${u.unit}');
          expect(u.grams!, greaterThan(0), reason: '${f.id}/${u.unit}');
        }
      }
    });
    test('عدد تخمینی هرگز «تأییدشده» نشان داده نمی‌شود', () {
      for (final f in repo.foods) {
        if (f.source?.contains('تخمین') ?? true) {
          expect(f.verified, isFalse, reason: f.id);
        }
      }
    });
    test('شناسه‌ی تکراری رد می‌شود', () {
      expect(
        () => FoodRepository.fromJsonString(
          '[{"id":"a","name_fa":"الف","units":[{"unit":"gram","name_fa":"گرم","grams":1}]},'
          '{"id":"a","name_fa":"ب","units":[{"unit":"gram","name_fa":"گرم","grams":1}]}]',
        ),
        throwsFormatException,
      );
    });
  });

  group('جستجوی فازی (معیار پذیرش)', () {
    test('«قرمه سبزي» با ي عربی ← قورمه‌سبزی', () {
      expect(first('قرمه سبزي'), 'ghormeh_sabzi');
    });
    test('شکل‌های مختلف نوشتن', () {
      expect(first('قورمه‌سبزی'), 'ghormeh_sabzi');
      expect(first('قورمه سبزي'), 'ghormeh_sabzi');
      expect(first('قورمهسبزی'), 'ghormeh_sabzi');
      expect(first(' قورمه  '), 'ghormeh_sabzi');
    });
    test('ک عربی', () {
      expect(first('كشك بادمجان'), 'kashk_bademjan');
    });
    test('ابتدای کلمه‌ها', () {
      expect(first('کباب کو'), 'kabab_koobideh');
      expect(first('سنگ'), 'nan_sangak');
    });
    test('غلط تایپی کوچک', () {
      expect(first('فسنجن'), 'fesenjan');
      expect(first('کوبیدع'), 'kabab_koobideh');
    });
    test('بدون نتیجه و عبارت خالی', () {
      expect(repo.search('پیتزای هاوایی'), isEmpty);
      expect(repo.search('   '), isEmpty);
    });
    test('مرتب‌سازی بر اساس پرتکرار در امتیاز برابر', () {
      // «نان» ابتدای نام سنگک و بربری است؛ امتیاز برابر.
      expect(first('نان', {'nan_barbari': 5}), 'nan_barbari');
      expect(first('نان', {'nan_sangak': 5}), 'nan_sangak');
    });
  });

  test('levenshtein', () {
    expect(levenshtein('کتاب', 'کباب'), 1);
    expect(levenshtein('abc', 'abc'), 0);
    expect(levenshtein('a', 'abcdef', max: 2), 3);
  });

  test('Food.serving با داده‌ی کامل (داده‌ی تستی)', () {
    final f = Food.fromJson({
      'id': 'x',
      'name_fa': 'تست',
      'category': 'rice',
      'per_100g': {'kcal': 130, 'protein': 2.5, 'carbs': 28, 'fat': 0.5},
      'units': [
        {'unit': 'kafgir', 'name_fa': 'کفگیر', 'grams': 60},
        {'unit': 'plate', 'name_fa': 'بشقاب', 'grams': null},
        {'unit': 'gram', 'name_fa': 'گرم', 'grams': 1},
      ],
      'default_unit': 'kafgir',
    });
    expect(f.hasNutrition, isTrue);
    final s = f.serving('kafgir', 1.5);
    expect(s.grams, 90);
    expect(s.nutrients.kcal, closeTo(117, 1e-9));
    expect(f.serving('plate', 1).nutrients, const Nutrients());
    expect(f.serving('gram', 200).nutrients.kcal, closeTo(260, 1e-9));
    // واحد ناشناخته ← واحد پیش‌فرض
    expect(f.unitOf('xyz').unit, 'kafgir');
  });
}
