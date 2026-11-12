import 'package:calorie_lens/app/providers.dart';
import 'package:calorie_lens/data/api/api_client.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('مرتب کردن آدرس: فقط https در انتشار', () {
    String? n(String v, {bool http = false}) =>
        ApiClient.normalizeUrl(v, allowHttp: http);
    expect(n('api.example.ir'), 'https://api.example.ir');
    expect(n(' https://api.example.ir/ '), 'https://api.example.ir');
    expect(n('https://example.ir/calorie//'), 'https://example.ir/calorie');
    expect(n('http://api.example.ir'), isNull);
    expect(n('http://192.168.1.5:8000', http: true), 'http://192.168.1.5:8000');
    expect(n('ftp://x.ir'), isNull);
    expect(n('https://x.ir/?a=1'), isNull);
    expect(n(''), isNull);
    expect(n('https://'), isNull);
  });

  test('بررسی سرور: فقط پاسخ health کالری‌لنز پذیرفته می‌شود', () async {
    Future<bool> probe(http.Response r) => ApiClient.probe(
      'https://x.ir',
      client: MockClient((req) async {
        expect(req.url.toString(), 'https://x.ir/health');
        return r;
      }),
    );
    expect(await probe(http.Response('{"ok":true,"foods":20}', 200)), isTrue);
    expect(await probe(http.Response('<html>hello</html>', 200)), isFalse);
    expect(await probe(http.Response('{"ok":true}', 200)), isFalse);
    expect(await probe(http.Response('{}', 500)), isFalse);
    expect(
      await ApiClient.probe(
        'https://x.ir',
        client: MockClient((_) async => throw http.ClientException('down')),
      ),
      isFalse,
    );
  });

  test('بدون آدرس سرور: خطای آفلاین، نه کرش', () async {
    final api = ApiClient(baseUrl: '', db: db);
    await expectLater(
      api.quota(),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.offline),
      ),
    );
  });

  testWidgets('وارد کردن آدرس: رد آدرس خراب و خاموش، ذخیره‌ی آدرس درست', (
    tester,
  ) async {
    await tester.runAsync(() => db.setSetting('api_token', 'old-token'));
    final probed = <String>[];
    var alive = false;
    await pumpApp(
      tester,
      db,
      onboardingDone: true,
      overrides: [
        serverProbeProvider.overrideWithValue((url) async {
          probed.add(url);
          return alive;
        }),
      ],
    );
    await tester.tap(find.text('پروفایل'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-info')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open-info')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('server-url')));
    await settle(tester);

    final input = find.byKey(const Key('server-url-input'));
    final save = find.byKey(const Key('server-url-save'));
    await tester.enterText(input, 'ftp://nope');
    await tester.tap(save);
    await settle(tester);
    expect(find.textContaining('آدرس درست نیست'), findsOneWidget);
    expect(probed, isEmpty);

    await tester.enterText(input, 'api.example.ir/');
    await tester.tap(save);
    await settle(tester);
    expect(probed, ['https://api.example.ir']);
    expect(find.textContaining('وصل نشدم'), findsOneWidget);
    expect(await tester.runAsync(() => db.getSetting(serverUrlKey)), isNull);

    alive = true;
    await tester.tap(save);
    await settle(tester);
    expect(find.byKey(const Key('server-url-input')), findsNothing);
    expect(find.text('https://api.example.ir'), findsOneWidget);
    expect(
      await tester.runAsync(() => db.getSetting(serverUrlKey)),
      'https://api.example.ir',
    );
    // توکن سرور قبلی دور ریخته می‌شود.
    expect(await tester.runAsync(() => db.getSetting('api_token')), '');
    await disposeApp(tester);
  });
}
