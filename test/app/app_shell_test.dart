import 'package:calorie_lens/app/app.dart';
import 'package:calorie_lens/app/providers.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const CalorieLensApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('۴ تب فارسی و جهت RTL', (tester) async {
    await pumpApp(tester);

    final nav = find.byType(NavigationBar);
    expect(nav, findsOneWidget);
    for (final label in ['امروز', 'پیشرفت', 'برنامه‌ها', 'پروفایل']) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      Directionality.of(tester.element(find.byType(NavigationBar))),
      TextDirection.rtl,
    );
  });

  testWidgets('جابه‌جایی بین تب‌ها', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('پیشرفت'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
  });

  testWidgets('تم تیره انتخاب و ذخیره می‌شود', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('پروفایل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تیره'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.dark,
    );
    expect(await db.getSetting('theme_mode'), 'dark');
    // سلب مسئولیت پزشکی همیشه هست.
    expect(find.textContaining('جایگزین پزشک'), findsOneWidget);
  });
}
