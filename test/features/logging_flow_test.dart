import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/core/utils/jalali_date.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/foods/food_repository.dart';
import 'package:calorie_lens/data/logs/food_log_repository.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:calorie_lens/l10n/app_localizations_fa.dart';
import 'package:calorie_lens/l10n/date_names.dart';
import 'package:calorie_lens/core/nutrition/serving.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final today = dateOnly(DateTime.now());
  final yesterday = DateTime(today.year, today.month, today.day - 1);

  Future<void> seedProfile(WidgetTester tester) => tester.runAsync(() {
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

  Future<void> seedLog(
    WidgetTester tester,
    DateTime day,
    String foodId, {
    Nutrients n = const Nutrients(),
  }) => tester.runAsync(
    () => FoodLogRepository(db).add(
      dayKey: dayKey(day),
      meal: MealType.lunch,
      foodId: foodId,
      quantity: 1,
      unit: 'piece',
      grams: null,
      nutrients: n,
      now: day.add(const Duration(hours: 12)),
    ),
  );

  Future<List<FoodLog>> logsOf(WidgetTester tester, DateTime day) async =>
      (await tester.runAsync(
        () => FoodLogRepository(db).watchDay(dayKey(day)).first,
      ))!;

  /// لمس شمرده‌شده (برای معیار «حداکثر ۳ لمس»).
  var taps = 0;
  Future<void> tap(WidgetTester tester, Finder f) async {
    taps++;
    await tester.ensureVisible(f);
    await tester.tap(f);
    await settle(tester);
  }

  testWidgets('منوی «ثبت غذا»: غذای اخیر با ۳ لمس', (tester) async {
    await seedProfile(tester);
    await seedLog(tester, yesterday, 'chelo');
    await pumpApp(tester, db, onboardingDone: true);

    taps = 0;
    await tap(tester, find.byKey(const Key('fab-log')));
    // منو: عکس/گالری/جستجو/صوتی همه فعال، و غذاهای اخیر.
    expect(find.text('به‌زودی'), findsNothing);
    expect(find.byKey(const Key('action-voice')), findsOneWidget);
    expect(find.byKey(const Key('action-camera')), findsOneWidget);
    expect(find.byKey(const Key('action-gallery')), findsOneWidget);
    expect(find.byKey(const Key('action-search')), findsOneWidget);
    expect(find.text('اخیر'), findsOneWidget);
    await tap(tester, find.byKey(const Key('sheet-food-chelo')));
    await tap(tester, find.byKey(const Key('save-log')));
    expect(taps, lessThanOrEqualTo(3));

    // برگشت به خانه، با آیتم ثبت‌شده.
    expect(find.byKey(const Key('fab-log')), findsOneWidget);
    expect(find.text('چلو'), findsOneWidget);
    final logs = await logsOf(tester, today);
    expect(logs.single.foodId, 'chelo');
    expect(logs.single.unit, 'kafgir');
    expect(logs.single.kcal, isNull); // داده‌ی نمونه null است، نه صفر.
    expect(find.byKey(const Key('incomplete-note')), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('جستجوی «قرمه سبزي» (ي عربی) ← قورمه‌سبزی و ثبت', (tester) async {
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true);

    await tester.tap(find.byKey(const Key('fab-log')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('action-search')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('search-field')), 'قرمه سبزي');
    await settle(tester);
    expect(find.byKey(const Key('food-ghormeh_sabzi')), findsOneWidget);
    expect(find.text('داده ناقص'), findsWidgets);

    await tester.tap(find.byKey(const Key('food-ghormeh_sabzi')));
    await settle(tester);
    // واحد پیش‌فرض ملاقه و دکمه‌ی + مقدار را ۱٫۵ می‌کند.
    expect(find.text('۱ ملاقه'), findsOneWidget);
    await tester.tap(find.byKey(const Key('qty-plus')));
    await settle(tester);
    expect(find.text('۱٫۵ ملاقه'), findsOneWidget);
    // شام را انتخاب کن.
    await tester.tap(find.text('شام').last);
    await settle(tester);
    expect(find.text('ثبت در شام'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-log')));
    await settle(tester);

    final log = (await logsOf(tester, today)).single;
    expect(log.mealType, MealType.dinner);
    expect(log.quantity, 1.5);
    expect(log.unit, 'ladle');
    expect(
      find.descendant(
        of: find.byKey(const Key('meal-dinner')),
        matching: find.text('خورش قورمه‌سبزی'),
      ),
      findsOneWidget,
    );
    await disposeApp(tester);
  });

  testWidgets('ثبت با جستجو از «+» وعده: ۳ لمس (به‌جز تایپ)', (tester) async {
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true);

    taps = 0;
    await tap(tester, find.byKey(const Key('add-dinner')));
    await tester.enterText(find.byKey(const Key('search-field')), 'دوغ');
    await settle(tester);
    await tap(tester, find.byKey(const Key('food-doogh')));
    expect(find.text('ثبت در شام'), findsOneWidget);
    await tap(tester, find.byKey(const Key('save-log')));
    expect(taps, 3);
    final log = (await logsOf(tester, today)).single;
    expect(log.foodId, 'doogh');
    expect(log.mealType, MealType.dinner);
    await disposeApp(tester);
  });

  testWidgets('منو بدون سابقه: بخش «اخیر» نیست', (tester) async {
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true);
    await tester.tap(find.byKey(const Key('fab-log')));
    await settle(tester);
    expect(find.text('اخیر'), findsNothing);
    expect(find.byKey(const Key('action-search')), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('رفتن به روز قبل و دیدن ثبت‌های آن', (tester) async {
    await seedProfile(tester);
    await seedLog(tester, yesterday, 'doogh');
    await pumpApp(tester, db, onboardingDone: true);
    expect(find.text('دوغ'), findsNothing);

    // اگر امروز شنبه است، دیروز در هفته‌ی قبل است.
    if (startOfWeek(today) == today) {
      await tester.tap(find.byKey(const Key('date-prev-week')));
      await settle(tester);
    }
    await tester.tap(find.byKey(Key('day-${dayKey(yesterday)}')));
    await settle(tester);
    expect(find.text('دوغ'), findsOneWidget);
    expect(
      find.text(AppLocalizationsFa().formatDateWithWeekday(yesterday)),
      findsOneWidget,
    );

    // «برو به امروز»
    await tester.tap(find.text('برو به امروز'));
    await settle(tester);
    expect(find.text('دوغ'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('ویرایش و حذف آیتم ثبت‌شده', (tester) async {
    await seedProfile(tester);
    await seedLog(tester, today, 'khorma');
    await pumpApp(tester, db, onboardingDone: true);

    final id = (await logsOf(tester, today)).single.id;
    await tester.tap(find.byKey(Key('log-$id')));
    await settle(tester);
    expect(find.text('ذخیره'), findsOneWidget);
    await tester.tap(find.byKey(const Key('qty-plus')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('save-log')));
    await settle(tester);
    expect((await logsOf(tester, today)).single.quantity, 1.5);

    await tester.tap(find.byKey(Key('log-$id')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('delete-log')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await settle(tester);
    expect(await logsOf(tester, today), isEmpty);
    expect(find.text('خرما'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('علاقه‌مندی و شمارنده‌ی آب', (tester) async {
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true);

    await tester.tap(find.byKey(const Key('water-plus')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('water-plus')));
    await settle(tester);
    expect(find.text('۲ لیوان'), findsOneWidget);
    await tester.tap(find.byKey(const Key('water-minus')));
    await settle(tester);
    expect(find.text('۱ لیوان'), findsOneWidget);

    await tester.tap(find.byKey(const Key('fab-log')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('action-search')));
    await settle(tester);
    expect(find.text('علاقه‌مندی‌ها'), findsNothing);
    await tester.enterText(find.byKey(const Key('search-field')), 'پنیر');
    await settle(tester);
    await tester.tap(find.byKey(const Key('food-panir')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('favorite')));
    await settle(tester);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('search-field')), '');
    await settle(tester);
    expect(find.text('علاقه‌مندی‌ها'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('با داده‌ی کامل: محاسبه‌ی زنده و حلقه‌ی کالری', (tester) async {
    // داده‌ی تستی (نه داده‌ی اپ) برای بررسی محاسبه.
    final foods = FoodRepository.fromJsonString('''
[{"id":"test_rice","name_fa":"برنج تستی","category":"rice",
  "per_100g":{"kcal":130,"protein":2.5,"carbs":28,"fat":0.5},
  "units":[{"unit":"kafgir","name_fa":"کفگیر","grams":60},
           {"unit":"gram","name_fa":"گرم","grams":1}],
  "default_unit":"kafgir","verified":true}]''');
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true, foods: foods);
    // هدف ۱۴۰۳ ← باقی‌مانده ۱۴۰۳
    expect(
      tester.widget<Text>(find.byKey(const Key('ring-value'))).data,
      '۱٬۴۰۳',
    );

    await tester.tap(find.byKey(const Key('fab-log')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('action-search')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('food-test_rice')));
    await settle(tester);
    // ۱ کفگیر = ۶۰ گرم ← ۷۸ کالری
    expect(
      tester.widget<Text>(find.byKey(const Key('detail-kcal'))).data,
      '۷۸',
    );
    await tester.tap(find.byKey(const Key('qty-plus')));
    await settle(tester);
    // ۱٫۵ کفگیر = ۹۰ گرم ← ۱۱۷ کالری
    expect(
      tester.widget<Text>(find.byKey(const Key('detail-kcal'))).data,
      '۱۱۷',
    );
    await tester.tap(find.byKey(const Key('save-log')));
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('ring-value'))).data,
      '۱٬۲۸۶',
    );
    expect(find.byKey(const Key('incomplete-note')), findsNothing);
    await disposeApp(tester);
  });
}
