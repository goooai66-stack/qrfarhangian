import 'dart:io';
import 'dart:typed_data';

import 'package:calorie_lens/app/providers.dart';
import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/core/nutrition/serving.dart';
import 'package:calorie_lens/core/platform/home_widget_service.dart';
import 'package:calorie_lens/core/platform/share_service.dart';
import 'package:calorie_lens/core/platform/store_rating.dart';
import 'package:calorie_lens/core/reminders/reminder_scheduler.dart';
import 'package:calorie_lens/core/utils/jalali_date.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/logs/food_log_repository.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:calorie_lens/data/scan/photo_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../helpers.dart';
import 'scan_flow_test.dart' show FakePhotoSource;

/// ابعاد PNG از سربرگ IHDR.
(int, int) pngSize(Uint8List b) {
  int u32(int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  return (u32(16), u32(20));
}

void main() {
  late AppDatabase db;
  final today = dateOnly(DateTime.now());
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

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
    DateTime day, {
    double kcal = 500,
  }) => tester.runAsync(
    () => FoodLogRepository(db).add(
      dayKey: dayKey(day),
      meal: MealType.lunch,
      foodId: 'chelo',
      quantity: 1,
      unit: 'gram',
      grams: 100,
      nutrients: Nutrients(kcal: kcal, protein: 20, carbs: 60, fat: 15),
      now: day.add(const Duration(hours: 12)),
    ),
  );

  Future<void> openProgress(WidgetTester tester) async {
    await tester.tap(find.text('پیشرفت'));
    await settle(tester);
  }

  testWidgets('ثبت وزن، نمودار و حذف', (tester) async {
    await seedProfile(tester); // یک ثبت وزن ۷۰ امروز
    await tester.runAsync(
      () => db
          .into(db.weightLogs)
          .insert(
            WeightLogsCompanion.insert(date: dayKey(ago(10)), weightKg: 71),
          ),
    );
    await pumpApp(tester, db, onboardingDone: true);
    await openProgress(tester);
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
      '۷۰ کیلوگرم',
    );

    await tester.tap(find.byKey(const Key('log-weight')));
    await settle(tester);
    // چرخ را کمی بالا بکش ← وزن کمتر.
    await tester.drag(find.byType(ListWheelScrollView), const Offset(0, 300));
    await settle(tester);
    await tester.tap(find.byKey(const Key('weight-save')));
    await settle(tester);
    final w = await tester.runAsync(() => db.select(db.weightLogs).get());
    expect(w, hasLength(2)); // امروز جایگزین شد
    final todayW = w!.firstWhere((e) => e.date == dayKey(today)).weightKg;
    expect(todayW, lessThan(70));
    expect(find.text('وزن'), findsWidgets);
    await disposeApp(tester);
  });

  testWidgets('زنجیره، نشان‌ها و نمودار کالری', (tester) async {
    await seedProfile(tester);
    for (final d in [ago(2), ago(1), today]) {
      await seedLog(tester, d, kcal: 600);
    }
    await tester.runAsync(
      () => FoodLogRepository(db).setWater(dayKey(ago(1)), 8),
    );
    await pumpApp(tester, db, onboardingDone: true);
    // پیام امتیاز (۳ روز) را رد کن تا مزاحم نشود.
    if (find.byKey(const Key('rate-later')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('rate-later')));
      await settle(tester);
    }
    await openProgress(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('streak-text'))).data,
      '۳ روز پیاپی',
    );
    expect(find.byKey(const Key('badge-firstLog-on')), findsOneWidget);
    expect(find.byKey(const Key('badge-streak3-on')), findsOneWidget);
    expect(find.byKey(const Key('badge-water8-on')), findsOneWidget);
    expect(find.byKey(const Key('badge-streak7-off')), findsOneWidget);
    expect(find.byKey(const Key('badge-firstKg-off')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('avg-kcal')));
    expect(
      tester.widget<Text>(find.byKey(const Key('avg-kcal'))).data,
      'میانگین روزهای ثبت‌شده: ۶۰۰ کالری',
    );
    await disposeApp(tester);
  });

  testWidgets('کارت اشتراک زنجیره: PNG ۱۰۸۰×۱۳۵۰', (tester) async {
    final share = FakeShareService();
    await seedProfile(tester);
    for (final d in [ago(2), ago(1), today]) {
      await seedLog(tester, d);
    }
    await pumpApp(tester, db, onboardingDone: true, share: share);
    if (find.byKey(const Key('rate-later')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('rate-later')));
      await settle(tester);
    }
    await openProgress(tester);
    await tester.tap(find.byKey(const Key('share-streak')));
    await settle(tester);
    expect(find.text('روز پیاپی'), findsOneWidget);
    await tester.tap(find.byKey(const Key('share-now')));
    for (var i = 0; i < 50 && share.shared.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(share.shared, hasLength(1));
    expect(pngSize(share.shared.single), (1080, 1350));
    expect(share.lastText, contains('کالری‌لنز'));
    await disposeApp(tester);
  });

  testWidgets('قبل و بعد: فقط محلی و کارت اشتراک', (tester) async {
    final share = FakeShareService();
    final dir = Directory.systemTemp.createTempSync('cl_ba');
    addTearDown(() => dir.deleteSync(recursive: true));
    final im = img.Image(width: 300, height: 400);
    img.fill(im, color: img.ColorRgb8(120, 160, 90));
    final photos = FakePhotoSource(img.encodeJpg(im));
    await seedProfile(tester);
    await pumpApp(
      tester,
      db,
      onboardingDone: true,
      share: share,
      overrides: [
        photoSourceProvider.overrideWithValue(photos),
        photoStoreProvider.overrideWithValue(
          PhotoStore(baseDir: () async => dir),
        ),
      ],
    );
    await openProgress(tester);
    for (final key in ['photo-before', 'photo-after']) {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(find.byKey(Key(key)));
      await settle(tester); // تا پایان انیمیشن برگه
      await tester.tap(find.text('گالری'));
      // ذخیره‌ی عکس (فشرده‌سازی در isolate) تمام شود.
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await settle(tester);
    }
    await pumpUntil(tester, find.byKey(const Key('share-before-after')));
    // عکس‌ها فقط در پوشه‌ی محلی اپ.
    expect(dir.listSync(recursive: true).whereType<File>(), hasLength(2));
    await tester.ensureVisible(find.byKey(const Key('share-before-after')));
    await tester.tap(find.byKey(const Key('share-before-after')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('share-now')));
    for (var i = 0; i < 100 && share.shared.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(pngSize(share.shared.single), (1080, 1350));
    await disposeApp(tester);
  });

  testWidgets('یادآورها: روشن کردن ← اجازه و زمان‌بندی', (tester) async {
    final reminders = FakeReminderScheduler();
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true, reminders: reminders);
    await tester.tap(find.text('پروفایل'));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('open-reminders')));
    await tester.tap(find.byKey(const Key('open-reminders')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('remind-meals')));
    await settle(tester);
    expect(reminders.applied!.meals, isTrue);
    expect(reminders.texts![reminders.texts!.keys.first]!.title, isNotEmpty);
    expect(find.text('۰۸:۳۰'), findsOneWidget); // صبحانه
    expect(
      await tester.runAsync(() => db.getSetting('reminders')),
      contains('"meals":true'),
    );

    // اجازه نداد ← ذخیره نمی‌شود.
    reminders.permission = false;
    await tester.tap(find.byKey(const Key('remind-meals'))); // خاموش
    await settle(tester);
    expect(reminders.applied!.meals, isFalse);
    await tester.tap(
      find.byKey(const Key('remind-water')),
    ); // روشن ← اجازه لازم
    await settle(tester);
    expect(
      find.text('اجازه‌ی اعلان داده نشد. از تنظیمات گوشی فعالش کن.'),
      findsOneWidget,
    );
    expect(reminders.applied!.water, isFalse);
    await disposeApp(tester);
  });

  testWidgets('معیار پذیرش: ویجت بعد از ثبت غذا به‌روز می‌شود', (tester) async {
    final widget = FakeHomeWidgetService();
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true, homeWidget: widget);
    await pumpUntil(tester, find.byKey(const Key('fab-log')));
    expect(
      widget.updates.last,
      const WidgetSnapshot(
        value: '۱٬۴۰۳',
        label: 'کالری باقی‌مانده',
        detail: '۰ از ۱٬۴۰۳ کالری',
      ),
    );
    await seedLog(tester, today, kcal: 403);
    await settle(tester);
    expect(widget.updates.last.value, '۱٬۰۰۰');
    expect(widget.updates.last.detail, '۴۰۳ از ۱٬۴۰۳ کالری');
    await seedLog(tester, today, kcal: 1100);
    await settle(tester);
    expect(widget.updates.last.label, 'بیشتر از هدف امروز');
    expect(widget.updates.last.value, '۱۰۰');
    await disposeApp(tester);
  });

  testWidgets('درخواست امتیاز بعد از ۳ روز؛ بعد از «امتیاز می‌دهم» دیگر نه', (
    tester,
  ) async {
    final rating = FakeStoreRating();
    await seedProfile(tester);
    for (final d in [ago(5), ago(3), ago(1)]) {
      await seedLog(tester, d);
    }
    await pumpApp(tester, db, onboardingDone: true, rating: rating);
    await pumpUntil(tester, find.text('از کالری‌لنز راضی هستی؟'));
    await tester.tap(find.byKey(const Key('rate-yes')));
    await settle(tester);
    expect(rating.opened, 1);
    expect(await tester.runAsync(() => db.getSetting('rating_state')), 'done');
    await disposeApp(tester);

    // اجرای بعدی اپ.
    await pumpApp(tester, db, onboardingDone: true, rating: rating);
    await settle(tester);
    expect(find.text('از کالری‌لنز راضی هستی؟'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('کمتر از ۳ روز ← درخواست امتیاز نیست', (tester) async {
    await seedProfile(tester);
    await seedLog(tester, today);
    await pumpApp(tester, db, onboardingDone: true);
    await settle(tester);
    expect(find.text('از کالری‌لنز راضی هستی؟'), findsNothing);
    await disposeApp(tester);
  });
}
