import 'dart:io';
import 'dart:math' as math;

import 'package:calorie_lens/app/config.dart';
import 'package:calorie_lens/app/theme.dart';
import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('کنتراست (WCAG AA، متن معمولی ≥ ۴٫۵)', () {
    for (final (name, theme) in [('روشن', lightTheme), ('تیره', darkTheme)]) {
      test('تم $name: دکمه‌ها و متن اصلی', () {
        final cs = theme.colorScheme;
        expect(contrast(cs.primary, cs.onPrimary), greaterThanOrEqualTo(4.5));
        expect(contrast(cs.surface, cs.onSurface), greaterThanOrEqualTo(4.5));
        expect(
          contrast(cs.primaryContainer, cs.onPrimaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        final fab = theme.floatingActionButtonTheme;
        expect(
          contrast(fab.backgroundColor!, fab.foregroundColor!),
          greaterThanOrEqualTo(4.5),
          reason: 'دکمه‌ی «ثبت غذا»',
        );
      });
    }
    test('زمینه‌های متن سفید', () {
      for (final c in [
        BrandColors.orangeDeep,
        BrandColors.greenDeep,
        BrandColors.greenDarker,
      ]) {
        expect(contrast(c, Colors.white), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('فونت بزرگ سیستم (۱٫۳ و ۲ برابر) بدون سرریز', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    for (final scale in [1.3, 2.0]) {
      testWidgets('مقیاس $scale: تب‌ها، جستجو، اشتراک، پیشرفت', (tester) async {
        await tester.runAsync(() {
          final input = NutritionInput(
            sex: Sex.female,
            birthDate: DateTime(DateTime.now().year - 30, 1, 1),
            heightCm: 165,
            weightKg: 70,
            goalWeightKg: 62,
            activityLevel: ActivityLevel.light,
            goalType: GoalType.lose,
            weeklyRateKg: 0.5,
          );
          return ProfileRepository(db)
              .saveOnboarding(input, calculatePlan(input));
        });
        // گوشی کوچک ۳۶۰dp
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(tester, db, onboardingDone: true);
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        await settle(tester);
        for (final tab in ['پیشرفت', 'برنامه‌ها', 'پروفایل', 'امروز']) {
          await tester.tap(find.text(tab).last);
          await settle(tester);
        }
        await tester.tap(find.byKey(const Key('fab-log')));
        await settle(tester);
        await tester.tap(find.byKey(const Key('action-search')));
        await settle(tester);
        await tester.tap(find.byType(BackButton));
        await settle(tester);
        await tester.tap(find.text('پروفایل').last);
        await settle(tester);
        await tester.scrollUntilVisible(
          find.byKey(const Key('premium-card')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        await tester.tap(find.byKey(const Key('premium-card')));
        await settle(tester);
        // اگر چیزی سرریز کند، تست با خطای RenderFlex شکست می‌خورد.
        expect(tester.takeException(), isNull);
        await disposeApp(tester);
      });
    }
  });

  test('نسخه‌ی اپ با pubspec یکی است', () {
    final pub = File('pubspec.yaml').readAsStringSync();
    final v = RegExp(r'^version:\s*([\d.]+)', multiLine: true).firstMatch(pub)!;
    expect(AppConfig.version, v.group(1));
  });
}
