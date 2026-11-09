import 'dart:io';
import 'dart:typed_data';

import 'package:calorie_lens/app/providers.dart';
import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/core/recognition/food_recognizer.dart';
import 'package:calorie_lens/core/utils/image_compress.dart';
import 'package:calorie_lens/core/utils/jalali_date.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/logs/food_log_repository.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:calorie_lens/data/scan/photo_store.dart';
import 'package:calorie_lens/features/scan/photo_source.dart';
import 'package:calorie_lens/features/scan/scan_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../helpers.dart';

class FakePhotoSource implements PhotoSource {
  FakePhotoSource(this.bytes);
  Uint8List? bytes;
  final picked = <ScanSource>[];

  @override
  Future<Uint8List?> pick(ScanSource source) async {
    picked.add(source);
    return bytes;
  }
}

Uint8List smallJpeg() {
  final im = img.Image(width: 64, height: 48);
  img.fill(im, color: img.ColorRgb8(200, 150, 50));
  return img.encodeJpg(im);
}

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakePhotoSource photos;
  late FakeFoodRecognizer recognizer;
  final today = dateOnly(DateTime.now());

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('cl_scan');
    photos = FakePhotoSource(smallJpeg());
    recognizer = FakeFoodRecognizer();
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> start(WidgetTester tester) async {
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
    final store = PhotoStore(baseDir: () async => dir);
    await pumpApp(
      tester,
      db,
      onboardingDone: true,
      overrides: [
        photoSourceProvider.overrideWithValue(photos),
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
  }

  Future<List<FoodLog>> logs(WidgetTester tester) async => (await tester
      .runAsync(() => FoodLogRepository(db).watchDay(dayKey(today)).first))!;

  Future<void> openScan(WidgetTester tester, String action) async {
    await tester.tap(find.byKey(const Key('fab-log')));
    await settle(tester);
    await tester.tap(find.byKey(Key(action)));
  }

  testWidgets('معیار پذیرش: عکس ← تشخیص ← ثبت در ناهار (FakeProvider)', (
    tester,
  ) async {
    await start(tester);
    await openScan(tester, 'action-camera');

    // بار اول: راهنمای کادر.
    await pumpUntil(tester, find.byKey(const Key('scan-guide-ok')));
    expect(find.text('بشقاب را از بالا و کامل در کادر بگیر.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-guide-ok')));

    await pumpUntil(tester, find.byKey(const Key('scan-save')));
    expect(photos.picked, [ScanSource.camera]);
    expect(find.text('چلو'), findsOneWidget);
    expect(find.text('کباب کوبیده'), findsOneWidget);
    expect(find.text('۱٫۵ کفگیر'), findsOneWidget);
    expect(find.text('۲ عدد'), findsOneWidget);
    // اطمینان بالا ← هشدار نیست.
    expect(find.byKey(const Key('scan-low-confidence')), findsNothing);
    // داده‌ی نمونه null است ← جمع «—»، نه «۰».
    await tester.ensureVisible(find.byKey(const Key('scan-total')));
    expect(
      tester.widget<Text>(find.byKey(const Key('scan-total'))).data,
      'کالری: —',
    );

    await tester.tap(find.text('ناهار').last);
    await tester.pump();
    expect(find.text('ثبت در ناهار'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-save')));
    await pumpUntil(tester, find.byKey(const Key('fab-log')));
    await settle(tester);

    final saved = await logs(tester);
    expect(saved.map((l) => l.foodId), ['chelo', 'kabab_koobideh']);
    expect(saved.every((l) => l.mealType == MealType.lunch), isTrue);
    expect(saved.every((l) => l.source == LogSource.photo), isTrue);
    expect(File(saved.first.photoPath!).existsSync(), isTrue);
    expect(saved.first.kcal, isNull); // داده‌ی نمونه null است
    expect(
      find.descendant(
        of: find.byKey(const Key('meal-lunch')),
        matching: find.text('چلو'),
      ),
      findsOneWidget,
    );
    // راهنما دیگر نمی‌آید.
    expect(await tester.runAsync(() => db.getSetting('scan_guide_seen')), '1');
    await disposeApp(tester);
  });

  testWidgets('ویرایش نتیجه: اطمینان پایین، حذف، مقدار، انتخاب غذای پیدانشده', (
    tester,
  ) async {
    recognizer.result = const RecognitionResult(
      isFood: true,
      notesFa: 'بخشی از بشقاب خارج از کادر است',
      items: [
        RecognizedItem(
          foodId: 'chelo',
          nameFa: 'چلو',
          quantity: 1,
          unit: 'kafgir',
          confidence: 0.9,
        ),
        RecognizedItem(
          foodId: null,
          nameFa: 'گوجه کبابی',
          quantity: 1,
          unit: 'piece',
          confidence: 0.4,
        ),
        RecognizedItem(
          foodId: 'doogh',
          nameFa: 'دوغ',
          quantity: 1,
          unit: 'glass',
          confidence: 0.95,
        ),
      ],
    );
    await start(tester);
    await openScan(tester, 'action-gallery'); // گالری: بدون راهنما
    await pumpUntil(tester, find.byKey(const Key('scan-save')));
    expect(photos.picked, [ScanSource.gallery]);
    expect(find.byKey(const Key('scan-low-confidence')), findsOneWidget);
    expect(find.text('بخشی از بشقاب خارج از کادر است'), findsOneWidget);
    expect(find.text('این غذا را پیدا نکردیم، انتخاب کن.'), findsOneWidget);

    // چلو: + ← ۱٫۵ کفگیر
    await tester.tap(find.byKey(const Key('scan-item-plus-0')));
    await tester.pump();
    expect(find.text('۱٫۵ کفگیر'), findsOneWidget);
    // دوغ را حذف کن.
    await tester.ensureVisible(find.byKey(const Key('scan-item-delete-2')));
    await tester.tap(find.byKey(const Key('scan-item-delete-2')));
    await tester.pump();
    expect(find.text('دوغ'), findsNothing);
    // آیتم پیدانشده ← انتخاب «کتلت» از جستجو.
    await tester.tap(find.byKey(const Key('scan-item-choose-1')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('search-field')), 'کتلت');
    await settle(tester);
    await tester.tap(find.byKey(const Key('food-kotlet')));
    await pumpUntil(tester, find.byKey(const Key('scan-save')));
    expect(find.text('کتلت'), findsOneWidget);
    expect(find.text('تشخیص: گوجه کبابی'), findsOneWidget);

    await tester.tap(find.text('شام').last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('scan-save')));
    await pumpUntil(tester, find.byKey(const Key('fab-log')));
    final saved = await logs(tester);
    expect(saved.map((l) => (l.foodId, l.quantity)), [
      ('chelo', 1.5),
      ('kotlet', 1.0),
    ]);
    expect(saved.every((l) => l.mealType == MealType.dinner), isTrue);
    await disposeApp(tester);
  });

  testWidgets('بدون اینترنت: صف آفلاین، پردازش بعد از وصل شدن و بررسی', (
    tester,
  ) async {
    recognizer.error = RecognitionException(ApiErrorKind.offline);
    await start(tester);
    await openScan(tester, 'action-gallery');
    await pumpUntil(tester, find.text('اینترنت نیست'));
    expect(
      find.text('عکس ذخیره شد؛ وقتی وصل شدی تحلیلش می‌کنیم.'),
      findsOneWidget,
    );
    expect(find.text('ثبت دستی'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('۱ عکس در صف تحلیل (بعد از وصل شدن)'), findsOneWidget);

    // وصل شد.
    recognizer.error = null;
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('fab-log'))),
    );
    final n = await tester.runAsync(
      () => container.read(pendingScanProcessorProvider).processAll(),
    );
    expect(n, 1);
    await settle(tester);
    expect(find.text('۱ عکس آماده‌ی بررسی است'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pending-review')));
    await pumpUntil(tester, find.byKey(const Key('scan-save')));
    expect(find.text('چلو'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-save')));
    await pumpUntil(tester, find.byKey(const Key('fab-log')));
    await settle(tester);
    expect(await logs(tester), hasLength(2));
    expect(find.byKey(const Key('pending-banner')), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('غذا نیست ← پیام و هیچ ثبتی', (tester) async {
    recognizer.result = const RecognitionResult(isFood: false, items: []);
    await start(tester);
    await openScan(tester, 'action-gallery');
    await pumpUntil(tester, find.text('غذایی در عکس پیدا نشد.'));
    expect(
      find.text('سهمیه‌ات کم نشد. دوباره امتحان کن یا دستی ثبت کن.'),
      findsOneWidget,
    );
    expect(await logs(tester), isEmpty);
    await disposeApp(tester);
  });

  testWidgets('سهمیه تمام ← پیشنهاد ثبت دستی (ویدیو/ویژه در مرحله‌ی ۵)', (
    tester,
  ) async {
    recognizer.error = RecognitionException(ApiErrorKind.quotaExceeded);
    await start(tester);
    await openScan(tester, 'action-gallery');
    await pumpUntil(tester, find.text('سهمیه‌ی اسکن امروز تمام شد'));
    expect(find.textContaining('دیدن یک ویدیو'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-primary')));
    await settle(tester);
    expect(find.byKey(const Key('search-field')), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('سرور شلوغ ← «دوباره» همان عکس را دوباره می‌فرستد', (
    tester,
  ) async {
    recognizer.error = RecognitionException(ApiErrorKind.busy);
    await start(tester);
    await openScan(tester, 'action-gallery');
    await pumpUntil(
      tester,
      find.text('سرور شلوغ است. کمی بعد دوباره امتحان کن.'),
    );
    recognizer.error = null;
    await tester.tap(find.byKey(const Key('scan-primary')));
    await pumpUntil(tester, find.byKey(const Key('scan-save')));
    expect(photos.picked, hasLength(1)); // عکس دوباره گرفته نشد
    expect(recognizer.calls, 2);
    await disposeApp(tester);
  });

  testWidgets('انصراف از گالری ← برگشت به خانه', (tester) async {
    photos.bytes = null;
    await start(tester);
    await openScan(tester, 'action-gallery');
    await pumpUntil(tester, find.byKey(const Key('fab-log')));
    expect(find.byKey(const Key('scan-save')), findsNothing);
    await disposeApp(tester);
  });
}
