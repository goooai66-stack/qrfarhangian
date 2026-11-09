import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/profile/profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> start(WidgetTester tester) async {
    final done = await tester.runAsync(
      () => ProfileRepository(db).hasProfile(),
    );
    await pumpApp(tester, db, onboardingDone: done!);
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await settle(tester);
  }

  testWidgets(
    'آنبوردینگ کامل: زن ۳۰ ساله، ۱۶۵، ۷۰، کم‌تحرک، ۰٫۵ ← ۱۴۰۳ کالری',
    (tester) async {
      await start(tester);
      expect(find.text('جنسیتت چیست؟'), findsOneWidget);

      // بدون انتخاب جنسیت، «بعدی» غیرفعال است.
      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('onboarding-next')),
      );
      expect(btn.onPressed, isNull);

      await tester.tap(find.text('زن'));
      await settle(tester);
      await next(tester); // تاریخ تولد (پیش‌فرض ۳۰ ساله)
      expect(find.text('۳۰ سال'), findsOneWidget);
      await next(tester); // بارداری (پیش‌فرض خیر)
      expect(find.text('باردار هستی یا به نوزاد شیر می‌دهی؟'), findsOneWidget);
      await next(tester); // قد ۱۶۵
      await next(tester); // وزن ۷۰
      await next(tester); // هدف: کاهش وزن (پیش‌فرض)
      expect(find.text('هدفت چیست؟'), findsOneWidget);
      await next(tester); // وزن هدف ۶۵
      await next(tester); // سرعت ۰٫۵
      expect(find.text('حدود ۱٬۴۰۳ کالری در روز'), findsOneWidget);
      await next(tester); // فعالیت: کم‌تحرک (پیش‌فرض)
      await next(tester); // نتیجه

      expect(find.text('برنامه‌ی شخصی تو'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('result-kcal'))).data,
        '۱٬۴۰۳',
      );
      expect(find.textContaining('جایگزین پزشک'), findsOneWidget);

      await next(tester); // «شروع کن» ← ذخیره ← Paywall نرم
      await pumpUntil(tester, find.byKey(const Key('paywall-not-now')));
      expect(find.text('کالری‌لنز ویژه 💎'), findsOneWidget);
      await tester.tap(find.byKey(const Key('paywall-not-now')));
      await settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget);

      final goal = await tester.runAsync(
        () => ProfileRepository(db).watchActiveGoal().first,
      );
      expect(goal!.kcal, 1403);

      // «بستن و باز کردن اپ»: آنبوردینگ تکرار نمی‌شود.
      await start(tester);
      expect(find.text('جنسیتت چیست؟'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      await disposeApp(tester);
    },
  );

  testWidgets('بدون پروفایل، هر مسیری به آنبوردینگ می‌رود', (tester) async {
    await start(tester);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('جنسیتت چیست؟'), findsOneWidget);
    await disposeApp(tester);
  });
}
