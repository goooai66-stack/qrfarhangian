import 'package:calorie_lens/app/app.dart';
import 'package:calorie_lens/app/providers.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// اپ کامل با دیتابیس تست.
Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  required bool onboardingDone,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialOnboardingDoneProvider.overrideWithValue(onboardingDone),
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
