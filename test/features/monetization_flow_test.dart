import 'dart:io';

import 'package:calorie_lens/app/providers.dart';
import 'package:calorie_lens/core/ads/ad_service.dart';
import 'package:calorie_lens/core/billing/billing_service.dart';
import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/core/recognition/food_recognizer.dart';
import 'package:calorie_lens/core/utils/image_compress.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/monetization/monetization.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:calorie_lens/data/scan/photo_store.dart';
import 'package:calorie_lens/features/scan/scan_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'scan_flow_test.dart' show FakePhotoSource, smallJpeg;

void main() {
  late AppDatabase db;
  final today = DateTime.now();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedProfile(WidgetTester tester, AppDatabase d) =>
      tester.runAsync(() {
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
        return ProfileRepository(d).saveOnboarding(input, calculatePlan(input));
      });

  group('ویدیوی جایزه‌دار (معیار پذیرش)', () {
    late FakeFoodRecognizer recognizer;
    late Directory dir;

    setUp(() {
      recognizer = FakeFoodRecognizer()
        ..error = RecognitionException(ApiErrorKind.quotaExceeded);
      dir = Directory.systemTemp.createTempSync('cl_mon');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<void> openQuotaDialog(
      WidgetTester tester, {
      required FakeAdService ads,
      required FakeMonetizationApi api,
    }) async {
      await seedProfile(tester, db);
      final store = PhotoStore(baseDir: () async => dir);
      await pumpApp(
        tester,
        db,
        onboardingDone: true,
        ads: ads,
        monetization: api,
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
      await tester.tap(find.byKey(const Key('fab-log')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('action-gallery')));
      await pumpUntil(tester, find.byKey(const Key('quota-video')));
    }

    testWidgets('دیدن کامل ← ۱ اسکن و تحلیل دوباره‌ی همان عکس', (tester) async {
      final ads = FakeAdService();
      final api = FakeMonetizationApi();
      await openQuotaDialog(tester, ads: ads, api: api);
      recognizer.error = null; // سرور حالا یک اسکن بیشتر می‌دهد
      await tester.tap(find.byKey(const Key('quota-video')));
      await pumpUntil(tester, find.byKey(const Key('scan-save')));
      expect(ads.rewardedShown, 1);
      expect(api.rewards, 1);
      expect(recognizer.calls, 2);
      await disposeApp(tester);
    });

    testWidgets('بستن زودهنگام ← پاداشی نیست', (tester) async {
      final ads = FakeAdService(rewardResult: RewardResult.skipped);
      final api = FakeMonetizationApi();
      await openQuotaDialog(tester, ads: ads, api: api);
      await tester.tap(find.byKey(const Key('quota-video')));
      await pumpUntil(
        tester,
        find.text('ویدیو کامل دیده نشد؛ اسکنی اضافه نشد.'),
      );
      expect(api.rewards, 0);
      expect(recognizer.calls, 1);
      expect(find.byKey(const Key('scan-save')), findsNothing);
      await disposeApp(tester);
    });

    testWidgets('سقف ۵ ویدیو در روز', (tester) async {
      final api = FakeMonetizationApi()..rewards = 5;
      await openQuotaDialog(tester, ads: FakeAdService(), api: api);
      await tester.tap(find.byKey(const Key('quota-video')));
      await pumpUntil(tester, find.text('سقف ویدیوی امروز پر شده است.'));
      expect(api.rewards, 5);
      await disposeApp(tester);
    });
  });

  group('تمام‌صفحه (معیار پذیرش)', () {
    test('نه در ۲ دقیقه‌ی اول، حداکثر ۴ بار در روز، نه برای ویژه', () async {
      var now = DateTime(2026, 11, 9, 10);
      final ads = FakeAdService();
      final api = FakeMonetizationApi(clock: () => now);
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          adServiceProvider.overrideWithValue(ads),
          monetizationApiProvider.overrideWithValue(api),
          monetizationEnabledProvider.overrideWithValue(true),
        ],
      );
      addTearDown(c.dispose);
      await c.read(entitlementProvider.future);
      final ad = c.read(adCoordinatorProvider);

      expect(await ad.afterLogSaved(), isFalse); // دقیقه‌ی ۰
      now = now.add(const Duration(minutes: 1, seconds: 59));
      expect(await ad.afterLogSaved(), isFalse); // هنوز ۲ دقیقه نشده
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(minutes: 4, seconds: 1));
        expect(await ad.afterLogSaved(), isTrue, reason: 'نمایش ${i + 1}');
        // بلافاصله بعدش نه (فاصله‌ی ۴ دقیقه).
        expect(await ad.afterLogSaved(), isFalse);
      }
      now = now.add(const Duration(minutes: 30));
      expect(await ad.afterLogSaved(), isFalse); // سقف ۴ در روز
      expect(ads.interstitialShown, 4);
      expect(await db.getSetting('ads_count'), '4');

      // کاربر ویژه
      c
          .read(entitlementProvider.notifier)
          .apply(
            QuotaStatus(
              premium: true,
              premiumUntil: now.add(const Duration(days: 30)),
            ),
          );
      now = now.add(const Duration(days: 1));
      expect(await ad.afterLogSaved(), isFalse);
      expect((await ad.watchVideoForScan()).name, 'unavailable');
      expect(ads.interstitialShown, 4);
    });
  });

  testWidgets(
    'خرید آزمایشی ← ویژه، بدون تبلیغ؛ بعد از نصب دوباره «بازیابی خرید»',
    (tester) async {
      final billing = FakeBillingService();
      final ads = FakeAdService(placeholders: true);
      await seedProfile(tester, db);
      await pumpApp(
        tester,
        db,
        onboardingDone: true,
        billing: billing,
        ads: ads,
        monetization: FakeMonetizationApi(),
      );
      // قبل از خرید: بنر جستجو هست.
      await tester.tap(find.byKey(const Key('fab-log')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('action-search')));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('fake-ad-bannerSearch')),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await settle(tester);

      await tester.tap(find.text('پروفایل'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('premium-card')));
      await settle(tester);
      expect(find.text('به‌صرفه‌ترین'), findsOneWidget);
      await tester.tap(find.byKey(const Key('paywall-buy')));
      await settle(tester);
      expect(find.text('اشتراک ویژه فعال شد 💎'), findsOneWidget);
      expect(billing.owned.single.plan, SubscriptionPlan.yearly);
      expect(find.textContaining('ویژه تا'), findsOneWidget);

      // بعد از خرید: بنر نیست. (اول SnackBar بسته شود.)
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      await tester.tap(find.text('امروز'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('fab-log')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('action-search')));
      await settle(tester);
      expect(find.byKey(const ValueKey('fake-ad-bannerSearch')), findsNothing);
      await disposeApp(tester);

      // نصب دوباره: دیتابیس و شناسه‌ی دستگاه نو، همان حساب فروشگاه.
      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      await seedProfile(tester, db2);
      await pumpApp(
        tester,
        db2,
        onboardingDone: true,
        billing: billing,
        monetization: FakeMonetizationApi(),
      );
      await tester.tap(find.text('پروفایل'));
      await settle(tester);
      expect(find.text('ارتقا به ویژه 💎'), findsOneWidget);
      await tester.tap(find.byKey(const Key('premium-card')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('paywall-restore')));
      await settle(tester);
      expect(find.text('اشتراک ویژه فعال شد 💎'), findsOneWidget);
      expect(find.textContaining('ویژه تا'), findsOneWidget);
      await disposeApp(tester);
    },
  );

  testWidgets('پرداخت فعال نیست (release بدون SDK) ← پیام روشن', (
    tester,
  ) async {
    await seedProfile(tester, db);
    await pumpApp(
      tester,
      db,
      onboardingDone: true,
      overridesBilling: true,
      overrides: [
        billingServiceProvider.overrideWithValue(
          const UnavailableBillingService('bazaar'),
        ),
      ],
    );
    await tester.tap(find.text('پروفایل'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('premium-card')));
    await settle(tester);
    expect(find.text('قیمت در فروشگاه'), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('paywall-buy')));
    await settle(tester);
    expect(find.text('پرداخت هنوز فعال نشده است.'), findsOneWidget);
    await disposeApp(tester);
  });
}
