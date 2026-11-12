import 'dart:io';

import 'package:calorie_lens/app/config.dart';
import 'package:calorie_lens/app/providers.dart';
import 'package:calorie_lens/core/ads/ad_service.dart';
import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/core/recognition/food_recognizer.dart';
import 'package:calorie_lens/core/utils/image_compress.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:calorie_lens/data/scan/photo_store.dart';
import 'package:calorie_lens/features/monetization/paywall_screen.dart';
import 'package:calorie_lens/features/scan/scan_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'scan_flow_test.dart' show FakePhotoSource, smallJpeg;

/// انتشار رایگان (MONETIZATION خاموش): هیچ اثری از اشتراک، تبلیغ و دعوت نیست.
void main() {
  late AppDatabase db;
  final today = DateTime.now();

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

  test('پیش‌فرض ساخت: درآمدزایی خاموش', () {
    expect(AppConfig.monetization, isFalse);
  });

  testWidgets('بعد از آنبوردینگ صفحه‌ی اشتراک نمی‌آید', (tester) async {
    await pumpApp(tester, db, onboardingDone: false, paid: false);
    await tester.tap(find.text('زن'));
    await settle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await settle(tester);
    }
    await pumpUntil(tester, find.byType(NavigationBar));
    await settle(tester);
    expect(find.byType(PaywallScreen), findsNothing);
    // علامت می‌ماند تا اگر بعداً اشتراک روشن شد، یک بار نشان داده شود.
    expect(
      await tester.runAsync(() => db.getSetting(SoftPaywallGate.pendingKey)),
      'pending',
    );
    await disposeApp(tester);
  });

  testWidgets('پروفایل: کارت ویژه و دعوت نیست؛ بقیه هست', (tester) async {
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true, paid: false);
    await tester.tap(find.text('پروفایل'));
    await settle(tester);
    expect(find.byKey(const Key('premium-card')), findsNothing);
    expect(find.byKey(const Key('open-invite')), findsNothing);
    expect(find.byKey(const Key('open-reminders')), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('سهمیه تمام شد: فقط ثبت دستی، بدون ویدیو و اشتراک؛ بدون تبلیغ', (
    tester,
  ) async {
    await seedProfile(tester);
    final dir = Directory.systemTemp.createTempSync('cl_free');
    addTearDown(() => dir.deleteSync(recursive: true));
    final recognizer = FakeFoodRecognizer()
      ..error = RecognitionException(ApiErrorKind.quotaExceeded);
    final store = PhotoStore(baseDir: () async => dir);
    final ads = FakeAdService(placeholders: true);
    await pumpApp(
      tester,
      db,
      onboardingDone: true,
      paid: false,
      ads: ads,
      overrides: [
        photoSourceProvider.overrideWithValue(FakePhotoSource(smallJpeg())),
        foodRecognizerProvider.overrideWithValue(recognizer),
        photoStoreProvider.overrideWithValue(store),
        scanServiceProvider.overrideWith(
          (ref) => ScanService(
            recognizer: recognizer,
            photos: store,
            pending: ref.watch(pendingScanRepositoryProvider),
            compress: (b) async => compressForScan(b),
          ),
        ),
      ],
    );
    expect(find.text('تبلیغ'), findsNothing);
    await tester.tap(find.byKey(const Key('fab-log')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('action-gallery')));
    await pumpUntil(tester, find.text('سهمیه‌ی اسکن امروز تمام شد'));
    expect(find.byKey(const Key('quota-video')), findsNothing);
    expect(find.byKey(const Key('quota-premium')), findsNothing);
    expect(find.text('ثبت دستی'), findsWidgets);
    expect(ads.rewardedShown, 0);
    await disposeApp(tester);
  });
}
