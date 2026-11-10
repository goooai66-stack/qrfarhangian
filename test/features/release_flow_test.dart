import 'dart:io';

import 'package:calorie_lens/app/providers.dart';
import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/core/nutrition/serving.dart';
import 'package:calorie_lens/core/reminders/reminder_scheduler.dart';
import 'package:calorie_lens/core/utils/jalali_date.dart';
import 'package:calorie_lens/data/community/community_api.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/logs/food_log_repository.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:calorie_lens/data/scan/photo_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  final today = dateOnly(DateTime.now());

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('cl_wipe');
  });
  tearDown(() async {
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
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
    await ProfileRepository(db).saveOnboarding(input, calculatePlan(input));
    await FoodLogRepository(db).add(
      dayKey: dayKey(today),
      meal: MealType.lunch,
      foodId: 'chelo',
      quantity: 1,
      unit: 'gram',
      grams: 100,
      nutrients: const Nutrients(),
    );
    final scans = Directory('${dir.path}/scans')..createSync();
    File('${scans.path}/a.jpg').writeAsBytesSync([1, 2, 3]);
  });

  Future<void> openInfo(WidgetTester tester) async {
    await tester.tap(find.text('پروفایل'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-info')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open-info')));
    await settle(tester);
  }

  testWidgets('حذف همه‌ی داده‌ها ← گوشی، عکس‌ها، سرور، یادآورها ← آنبوردینگ', (
    tester,
  ) async {
    final community = FakeCommunityApi();
    final reminders = FakeReminderScheduler();
    await seed(tester);
    await pumpApp(
      tester,
      db,
      onboardingDone: true,
      community: community,
      reminders: reminders,
      overrides: [
        photoStoreProvider.overrideWithValue(
          PhotoStore(baseDir: () async => dir),
        ),
      ],
    );
    await openInfo(tester);
    expect(find.text('نسخه‌ی ۱.۰.۰'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-all')));
    await settle(tester);
    // بدون نوشتن «حذف» دکمه غیرفعال است.
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('delete-confirm')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('delete-confirm-input')),
      'حذف',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await pumpUntil(tester, find.text('جنسیتت چیست؟'));

    expect(community.serverDeleted, isTrue);
    expect(reminders.applied!.anyEnabled, isFalse);
    expect(Directory('${dir.path}/scans').existsSync(), isFalse);
    final counts = await tester.runAsync(
      () async => [
        (await db.select(db.userProfiles).get()).length,
        (await db.select(db.foodLogs).get()).length,
        (await db.select(db.goals).get()).length,
        (await db.select(db.appSettings).get()).length,
      ],
    );
    expect(counts, [0, 0, 0, 0]);
    await disposeApp(tester);
  });

  testWidgets('سرور در دسترس نیست ← داده‌های گوشی پاک و پیام روشن', (
    tester,
  ) async {
    final community = FakeCommunityApi()..failDelete = true;
    await seed(tester);
    await pumpApp(tester, db, onboardingDone: true, community: community);
    await openInfo(tester);
    await tester.tap(find.byKey(const Key('delete-all')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('delete-confirm-input')),
      'حذف',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await pumpUntil(tester, find.text('جنسیتت چیست؟'));
    expect(find.textContaining('اتصال به سرور برقرار نشد'), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.foodLogs).get()), isEmpty);
    await disposeApp(tester);
  });

  testWidgets('حریم خصوصی، سلب مسئولیت و خاموش کردن آمار', (tester) async {
    await seed(tester);
    await pumpApp(tester, db, onboardingDone: true);
    await openInfo(tester);
    await tester.tap(find.byKey(const Key('open-privacy')));
    await settle(tester);
    expect(find.textContaining('هرگز آپلود نمی‌شوند'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-disclaimer')));
    await settle(tester);
    expect(find.textContaining('جایگزین پزشک'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.byKey(const Key('analytics-toggle')));
    await settle(tester);
    expect(
      await tester.runAsync(() => db.getSetting('analytics_enabled')),
      'false',
    );
    await disposeApp(tester);
  });
}
