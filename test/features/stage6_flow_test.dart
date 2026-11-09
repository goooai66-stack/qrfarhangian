import 'package:calorie_lens/core/nutrition/nutrition_calculator.dart';
import 'package:calorie_lens/core/nutrition/serving.dart';
import 'package:calorie_lens/core/platform/speech_service.dart';
import 'package:calorie_lens/core/recognition/food_recognizer.dart';
import 'package:calorie_lens/core/recognition/text_parser.dart';
import 'package:calorie_lens/core/reminders/reminder_plan.dart';
import 'package:calorie_lens/core/reminders/reminder_scheduler.dart';
import 'package:calorie_lens/core/utils/jalali_date.dart';
import 'package:calorie_lens/data/community/community_api.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/logs/food_log_repository.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const sentence = 'ناهار یه بشقاب قیمه با برنج و یه دوغ خوردم';

void main() {
  late AppDatabase db;
  final today = dateOnly(DateTime.now());
  final yesterday = DateTime(today.year, today.month, today.day - 1);

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

  Future<List<FoodLog>> logsOf(WidgetTester tester, DateTime d) async =>
      (await tester.runAsync(
        () => FoodLogRepository(db).watchDay(dayKey(d)).first,
      ))!;

  Future<void> openVoice(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('fab-log')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('action-voice')));
    await settle(tester);
  }

  testWidgets('معیار پذیرش: جمله‌ی تایپی ← ۳ آیتم درست در ناهار', (
    tester,
  ) async {
    final parser = FakeTextParser();
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true, textParser: parser);
    await openVoice(tester);
    await tester.enterText(find.byKey(const Key('voice-text')), sentence);
    await tester.pump();
    await tester.tap(find.byKey(const Key('voice-send')));
    await pumpUntil(tester, find.byKey(const Key('scan-save')));
    expect(parser.texts, [sentence]);
    expect(find.text('خورش قیمه'), findsOneWidget);
    expect(find.text('چلو'), findsOneWidget);
    expect(find.text('دوغ'), findsOneWidget);
    // وعده از خود جمله: «ثبت در ناهار»
    expect(find.text('ثبت در ناهار'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-save')));
    await pumpUntil(tester, find.byKey(const Key('fab-log')));
    final logs = await logsOf(tester, today);
    expect(logs.map((l) => l.foodId), ['gheymeh', 'chelo', 'doogh']);
    expect(logs.every((l) => l.mealType == MealType.lunch), isTrue);
    expect(logs.every((l) => l.source == LogSource.text), isTrue);
    expect(logs.every((l) => l.photoPath == null), isTrue);
    await disposeApp(tester);
  });

  testWidgets('نگه دار و بگو ← منبع «صوتی»', (tester) async {
    final speech = FakeSpeechService(text: sentence);
    final parser = FakeTextParser();
    await seedProfile(tester);
    await pumpApp(
      tester,
      db,
      onboardingDone: true,
      textParser: parser,
      speech: speech,
    );
    await openVoice(tester);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('voice-hold'))),
    );
    await tester.pump(const Duration(seconds: 1)); // نگه داشتن
    await settle(tester);
    expect(speech.listening, isTrue);
    expect(find.text('در حال شنیدن…'), findsOneWidget);
    await g.up();
    await pumpUntil(tester, find.byKey(const Key('scan-save')));
    expect(parser.texts, [sentence]);
    await tester.tap(find.byKey(const Key('scan-save')));
    await pumpUntil(tester, find.byKey(const Key('fab-log')));
    final logs = await logsOf(tester, today);
    expect(logs, hasLength(3));
    expect(logs.every((l) => l.source == LogSource.voice), isTrue);
    await disposeApp(tester);
  });

  testWidgets('گفتار در دسترس نیست ← پیام و تایپ', (tester) async {
    await seedProfile(tester);
    await pumpApp(
      tester,
      db,
      onboardingDone: true,
      speech: FakeSpeechService(available: false),
    );
    await openVoice(tester);
    expect(
      find.text('تشخیص گفتار روی این گوشی در دسترس نیست؛ جمله را تایپ کن.'),
      findsOneWidget,
    );
    await disposeApp(tester);
  });

  testWidgets('سهمیه‌ی صوتی تمام / جمله‌ی غیرغذایی', (tester) async {
    final parser = FakeTextParser()
      ..error = RecognitionException(ApiErrorKind.voiceQuotaExceeded);
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true, textParser: parser);
    await openVoice(tester);
    await tester.enterText(find.byKey(const Key('voice-text')), 'یه دوغ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('voice-send')));
    await settle(tester);
    expect(
      find.text('سهمیه‌ی ثبت صوتی امروز تمام شد. ثبت دستی همیشه رایگان است.'),
      findsOneWidget,
    );
    parser
      ..error = null
      ..result = const RecognitionResult(isFood: false, items: []);
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byKey(const Key('voice-send')));
    await settle(tester);
    expect(
      find.text('در این جمله غذایی پیدا نشد. دوباره بگو یا بنویس.'),
      findsOneWidget,
    );
    await disposeApp(tester);
  });

  testWidgets('کپی وعده‌ی دیروز', (tester) async {
    await seedProfile(tester);
    await tester.runAsync(() async {
      final r = FoodLogRepository(db);
      for (final id in ['chelo', 'gheymeh']) {
        await r.add(
          dayKey: dayKey(yesterday),
          meal: MealType.lunch,
          foodId: id,
          quantity: 1,
          unit: 'gram',
          grams: 100,
          nutrients: const Nutrients(),
        );
      }
    });
    await pumpApp(tester, db, onboardingDone: true);
    await tester.ensureVisible(find.byKey(const Key('meal-menu-lunch')));
    await tester.tap(find.byKey(const Key('meal-menu-lunch')));
    await settle(tester);
    await tester.tap(find.text('کپی از دیروز'));
    await settle(tester);
    expect(find.text('۲ قلم از دیروز کپی شد'), findsOneWidget);
    expect((await logsOf(tester, today)).map((l) => l.foodId), [
      'chelo',
      'gheymeh',
    ]);
    await disposeApp(tester);
  });

  testWidgets('غذای ترکیبی: ذخیره از وعده و ثبت دوباره از جستجو', (
    tester,
  ) async {
    await seedProfile(tester);
    await tester.runAsync(() async {
      final r = FoodLogRepository(db);
      for (final id in ['nan_barbari', 'panir']) {
        await r.add(
          dayKey: dayKey(today),
          meal: MealType.breakfast,
          foodId: id,
          quantity: 1,
          unit: 'piece',
          grams: null,
          nutrients: const Nutrients(),
        );
      }
    });
    await pumpApp(tester, db, onboardingDone: true);
    await tester.tap(find.byKey(const Key('meal-menu-breakfast')));
    await settle(tester);
    await tester.tap(find.text('ذخیره به‌عنوان غذای ترکیبی'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('custom-meal-name')),
      'صبحانه‌ی همیشگی',
    );
    await tester.tap(find.byKey(const Key('custom-meal-save')));
    await settle(tester);

    // فردا… (اینجا: همان روز، وعده‌ی شام) ← «+» شام ← غذاهای ترکیبی من.
    await tester.pump(const Duration(seconds: 5)); // بسته شدن SnackBar
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('add-dinner')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-dinner')));
    await settle(tester);
    expect(find.text('غذاهای ترکیبی من'), findsOneWidget);
    await tester.tap(find.text('صبحانه‌ی همیشگی'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('custom-log')));
    await settle(tester);
    final logs = await logsOf(tester, today);
    expect(
      logs.where((l) => l.mealType == MealType.dinner).map((l) => l.foodId),
      ['nan_barbari', 'panir'],
    );
    await disposeApp(tester);
  });

  testWidgets('حالت رمضان: سحر و افطار، بدون ناهار، یادآورها', (tester) async {
    final reminders = FakeReminderScheduler();
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true, reminders: reminders);
    expect(find.byKey(const Key('meal-lunch')), findsOneWidget);
    await tester.tap(find.text('پروفایل'));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('open-reminders')));
    await tester.tap(find.byKey(const Key('open-reminders')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('ramadan-mode')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('remind-meals')));
    await settle(tester);
    final plan = planReminders(reminders.applied!);
    expect(
      plan.map((p) => p.kind),
      containsAll([ReminderKind.suhoor, ReminderKind.iftar]),
    );
    expect(plan.map((p) => p.kind), isNot(contains(ReminderKind.lunch)));
    expect(reminders.texts![ReminderKind.suhoor]!.title, 'وقت سحر 🌙');

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.text('امروز'));
    await settle(tester);
    expect(find.text('سحر'), findsWidgets);
    expect(find.text('افطار'), findsWidgets);
    expect(find.byKey(const Key('meal-lunch')), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('کد دعوت: نمایش، کد خود رد، کد دوست ← ویژه', (tester) async {
    final community = FakeCommunityApi(code: 'ABC234');
    await seedProfile(tester);
    await pumpApp(tester, db, onboardingDone: true, community: community);
    await tester.tap(find.text('پروفایل'));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('open-invite')));
    await tester.tap(find.byKey(const Key('open-invite')));
    await settle(tester);
    expect(find.text('ABC234'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('invite-input')), 'abc234');
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite-redeem')));
    await settle(tester);
    expect(find.text('کد خودت را نمی‌توانی وارد کنی.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('invite-input')), 'XYZ789');
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite-redeem')));
    await settle(tester);
    expect(find.text('هدیه فعال شد 🎁'), findsOneWidget);
    expect(community.redeemed, 'XYZ789');
    // بعد از ثبت، کادر کد دیگر نیست (فقط یک‌بار).
    expect(find.byKey(const Key('invite-input')), findsNothing);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.textContaining('ویژه تا'), findsOneWidget);
    await disposeApp(tester);
  });
}
