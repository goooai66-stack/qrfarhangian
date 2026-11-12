import 'dart:io';

import 'package:calorie_lens/app/app.dart';
import 'package:calorie_lens/app/providers.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/core/ads/ad_service.dart';
import 'package:calorie_lens/core/analytics/analytics.dart';
import 'package:calorie_lens/core/billing/billing_service.dart';
import 'package:calorie_lens/core/platform/home_widget_service.dart';
import 'package:calorie_lens/core/platform/speech_service.dart';
import 'package:calorie_lens/core/recognition/text_parser.dart';
import 'package:calorie_lens/data/community/community_api.dart';
import 'package:calorie_lens/data/monetization/monetization.dart';
import 'package:calorie_lens/core/platform/share_service.dart';
import 'package:calorie_lens/core/platform/store_rating.dart';
import 'package:calorie_lens/core/reminders/reminder_scheduler.dart';
import 'package:calorie_lens/data/foods/food_repository.dart';
import 'package:calorie_lens/features/home/rating_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// اپ کامل با دیتابیس تست.
Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  required bool onboardingDone,
  List<Override> overrides = const [],
  FoodRepository? foods,
  FakeReminderScheduler? reminders,
  FakeHomeWidgetService? homeWidget,
  FakeShareService? share,
  FakeStoreRating? rating,
  FakeAdService? ads,
  FakeBillingService? billing,
  FakeMonetizationApi? monetization,
  bool overridesBilling = false,
  FakeTextParser? textParser,
  FakeSpeechService? speech,
  FakeCommunityApi? community,
  FakeEventSender? events,
  bool paid = true,
}) async {
  final foodRepo = foods ?? loadAppFoods();
  RatingPromptGate.checkedThisSession = false;
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialOnboardingDoneProvider.overrideWithValue(onboardingDone),
        foodRepositoryProvider.overrideWith((ref) => foodRepo),
        // سرویس‌های بومی در تست جعلی‌اند.
        reminderSchedulerProvider.overrideWithValue(
          reminders ?? FakeReminderScheduler(),
        ),
        homeWidgetServiceProvider.overrideWithValue(
          homeWidget ?? FakeHomeWidgetService(),
        ),
        shareServiceProvider.overrideWithValue(share ?? FakeShareService()),
        storeRatingProvider.overrideWithValue(rating ?? FakeStoreRating()),
        adServiceProvider.overrideWithValue(ads ?? FakeAdService()),
        if (billing != null || !overridesBilling)
          billingServiceProvider.overrideWithValue(
            billing ?? FakeBillingService(),
          ),
        monetizationApiProvider.overrideWithValue(
          monetization ?? FakeMonetizationApi(),
        ),
        textFoodParserProvider.overrideWithValue(
          textParser ?? FakeTextParser(),
        ),
        speechServiceProvider.overrideWithValue(speech ?? FakeSpeechService()),
        communityApiProvider.overrideWithValue(community ?? FakeCommunityApi()),
        // بیشتر تست‌ها مسیر اشتراک و تبلیغ را می‌سنجند؛ پیش‌فرض اپ خاموش است.
        monetizationEnabledProvider.overrideWithValue(paid),
        ...overrides,
      ],
      child: const CalorieLensApp(),
    ),
  );
  await settle(tester);
}

/// صبر برای کوئری‌های Drift (که بیرون از زمان جعلی تست کامل می‌شوند) و
/// سپس پایان انیمیشن‌ها.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
}

/// پایان تست ویجت: درخت را بردار تا streamهای Drift لغو شوند و تایمر
/// صفرثانیه‌ای لغوشان اجرا شود (وگرنه «A Timer is still pending»).
Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// داده‌ی نمونه‌ی ثابت برای تست‌های رابط کاربری: ۲۰ غذا با مقادیر خالی
/// (مسیر «داده ناقص»). پایگاه واقعی اپ در test/data/foods سنجیده می‌شود.
FoodRepository loadAppFoods() => FoodRepository.fromJsonString(
  File('test/fixtures/foods_sample.json').readAsStringSync(),
);

/// تا وقتی [finder] پیدا شود پمپ می‌کند (برای صفحه‌هایی با انیمیشن بی‌پایان
/// که pumpAndSettle در آن‌ها تمام نمی‌شود). کارهای واقعی (دیتابیس، فایل) هم
/// در runAsync جلو می‌روند.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 200,
}) async {
  for (var i = 0; i < maxTries; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('پیدا نشد: $finder');
}
