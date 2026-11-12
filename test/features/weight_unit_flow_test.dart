import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/core/utils/jalali_date.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  final today = dateOnly(DateTime.now());

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await settle(tester);
  }

  testWidgets('آنبوردینگ با پوند: نمایش پوند، ذخیره کیلوگرم، همان برنامه', (
    tester,
  ) async {
    await pumpApp(tester, db, onboardingDone: false);
    await tester.tap(find.text('زن'));
    await settle(tester);
    await next(tester); // ← تاریخ تولد
    await next(tester); // ← بارداری
    await next(tester); // ← قد
    await next(tester); // ← وزن
    // مرحله‌ی وزن: کیلوگرم پیش‌فرض است.
    expect(find.text('۷۰'), findsWidgets);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('weight-unit')),
        matching: find.text('پوند'),
      ),
    );
    await settle(tester);
    expect(find.text('۱۵۴'), findsWidgets); // ۷۰ کیلو ≈ ۱۵۴ پوند
    expect(await tester.runAsync(() => db.getSetting('weight_unit')), 'lb');

    await next(tester); // ← هدف (کاهش وزن)
    await next(tester); // ← وزن هدف
    expect(find.textContaining('پوند'), findsWidgets);
    await next(tester); // ← سرعت
    expect(find.textContaining('۱٫۱ پوند در هفته'), findsOneWidget);
    // تغییر واحد، برنامه را عوض نمی‌کند.
    expect(find.text('حدود ۱٬۴۰۳ کالری در روز'), findsOneWidget);
    await next(tester); // ← فعالیت
    await next(tester); // ← نتیجه
    expect(find.textContaining('رسیدن به ۱۴۳٫۳ پوند'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('result-kcal'))).data,
      '۱٬۴۰۳',
    );
    await next(tester);
    await pumpUntil(tester, find.byKey(const Key('paywall-not-now')));
    await tester.tap(find.byKey(const Key('paywall-not-now')));
    await settle(tester);

    final p = await tester.runAsync(() => ProfileRepository(db).getProfile());
    expect(p!.startWeightKg, 70); // ذخیره همیشه کیلوگرم
    expect(p.goalWeightKg, 65);
    await disposeApp(tester);
  });

  testWidgets('تنظیم واحد در پروفایل ← پیشرفت به پوند؛ ثبت وزن به پوند', (
    tester,
  ) async {
    await tester.runAsync(() {
      final input = NutritionInput(
        sex: Sex.female,
        birthDate: DateTime(today.year - 30, 1, 1),
        heightCm: 165,
        weightKg: 70,
        goalWeightKg: 62,
        activityLevel: ActivityLevel.light,
        goalType: GoalType.lose,
        weeklyRateKg: 0.5,
      );
      return ProfileRepository(db).saveOnboarding(input, calculatePlan(input));
    });
    await pumpApp(tester, db, onboardingDone: true);

    await tester.tap(find.text('پروفایل'));
    await settle(tester);
    expect(find.text('۶۲ کیلوگرم'), findsOneWidget);
    final toggle = find.byKey(const Key('settings-weight-unit'));
    await tester.scrollUntilVisible(toggle, 200);
    await tester.tap(find.descendant(of: toggle, matching: find.text('پوند')));
    await settle(tester);
    expect(await tester.runAsync(() => db.getSetting('weight_unit')), 'lb');
    await tester.scrollUntilVisible(find.text('۱۳۶٫۷ پوند'), -200);
    expect(find.text('۱۳۶٫۷ پوند'), findsOneWidget); // وزن هدف ۶۲ کیلو

    await tester.tap(find.text('پیشرفت'));
    await settle(tester);
    expect(
      tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(const Key('weight-current')),
                  matching: find.byType(Text),
                )
                .last,
          )
          .data,
      '۱۵۴٫۳ پوند',
    );

    await tester.tap(find.byKey(const Key('log-weight')));
    await settle(tester);
    expect(find.text('پوند'), findsWidgets);
    await tester.drag(find.byType(ListWheelScrollView), const Offset(0, 300));
    await settle(tester);
    await tester.tap(find.byKey(const Key('weight-save')));
    await settle(tester);
    final w = await tester.runAsync(() => db.select(db.weightLogs).get());
    final kg = w!.single.weightKg;
    expect(kg, lessThan(70));
    // گام ۰٫۲ پوند ← ذخیره با دو رقم اعشار کیلوگرم، بدون گم شدن دقت.
    expect((kg * 100).round() / 100, kg);
    await disposeApp(tester);
  });
}
