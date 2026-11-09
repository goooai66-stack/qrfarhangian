import 'package:calorie_lens/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('۴ تب فارسی و جهت RTL', (tester) async {
    await pumpApp(tester, db, onboardingDone: true);

    final nav = find.byType(NavigationBar);
    expect(nav, findsOneWidget);
    for (final label in ['امروز', 'پیشرفت', 'برنامه‌ها', 'پروفایل']) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(Directionality.of(tester.element(nav)), TextDirection.rtl);
    await disposeApp(tester);
  });

  testWidgets('جابه‌جایی بین تب‌ها', (tester) async {
    await pumpApp(tester, db, onboardingDone: true);
    await tester.tap(find.text('پیشرفت'));
    await settle(tester);
    expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('تم تیره انتخاب و ذخیره می‌شود', (tester) async {
    await pumpApp(tester, db, onboardingDone: true);
    await tester.tap(find.text('پروفایل'));
    await settle(tester);
    await tester.tap(find.text('تیره'));
    await settle(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.dark,
    );
    expect(await tester.runAsync(() => db.getSetting('theme_mode')), 'dark');
    // سلب مسئولیت پزشکی همیشه هست.
    expect(find.textContaining('جایگزین پزشک'), findsOneWidget);
    await disposeApp(tester);
  });
}
