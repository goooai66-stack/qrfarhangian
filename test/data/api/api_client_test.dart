import 'dart:convert';
import 'dart:io';

import 'package:calorie_lens/data/api/api_client.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  ApiClient client(Future<http.Response> Function(http.Request) handler) =>
      ApiClient(
        baseUrl: 'http://test/',
        db: db,
        httpClient: MockClient(handler),
      );

  test('ثبت دستگاه، ذخیره‌ی توکن و ارسال عکس', () async {
    var registrations = 0;
    String? deviceId;
    late http.Request scanReq;
    final api = client((req) async {
      if (req.url.path == '/auth/device') {
        registrations++;
        deviceId = (jsonDecode(req.body) as Map)['device_id'] as String;
        return json({'token': 'tok1'});
      }
      scanReq = req;
      return json({'scan_id': 's1', 'is_food': true, 'items': []});
    });
    final r = await api.scan([0xFF, 0xD8, 0xFF, 1]);
    expect(r['scan_id'], 's1');
    expect(scanReq.url.toString(), 'http://test/scan');
    expect(scanReq.headers['Authorization'], 'Bearer tok1');
    expect(scanReq.headers['content-type'], startsWith('multipart/form-data'));
    expect(deviceId, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(await db.getSetting('api_token'), 'tok1');

    // دفعه‌ی بعد ثبت دوباره نمی‌شود و همان device_id می‌ماند.
    await api.scan([0xFF, 0xD8, 0xFF, 2]);
    expect(registrations, 1);
    expect(await db.getSetting('device_id'), deviceId);
  });

  test('توکن باطل ← یک‌بار ثبت دوباره و تکرار درخواست', () async {
    await db.setSetting('api_token', 'old');
    var scans = 0;
    final api = client((req) async {
      if (req.url.path == '/auth/device') return json({'token': 'new'});
      scans++;
      if (req.headers['Authorization'] == 'Bearer old') {
        return json({
          'error': {'code': 'unauthorized'},
        }, 401);
      }
      return json({'used': 0, 'limit': 3, 'remaining': 3});
    });
    expect((await api.quota())['remaining'], 3);
    expect(scans, 2);
    expect(await db.getSetting('api_token'), 'new');
  });

  group('دسته‌بندی خطا', () {
    Future<ApiErrorKind> kindFor(http.Response res) async {
      await db.setSetting('api_token', 't');
      final api = client((req) async => res);
      try {
        await api.scan([1]);
      } on ApiException catch (e) {
        return e.kind;
      }
      fail('خطا انتظار می‌رفت');
    }

    test('کدهای سرور', () async {
      expect(
        await kindFor(
          json({
            'error': {'code': 'quota_exceeded'},
          }, 429),
        ),
        ApiErrorKind.quotaExceeded,
      );
      expect(
        await kindFor(
          json({
            'error': {'code': 'rate_limited'},
          }, 429),
        ),
        ApiErrorKind.rateLimited,
      );
      expect(await kindFor(json({}, 503)), ApiErrorKind.busy);
      expect(await kindFor(json({}, 502)), ApiErrorKind.busy);
      expect(await kindFor(json({}, 504)), ApiErrorKind.timeout);
      expect(await kindFor(json({}, 413)), ApiErrorKind.badImage);
      expect(await kindFor(http.Response('oops', 500)), ApiErrorKind.server);
    });
  });

  test('بدون اینترنت ← offline', () async {
    final api = client((req) async => throw const SocketException('no net'));
    expect(
      () => api.quota(),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.offline),
      ),
    );
  });

  test('مهلت تمام شد ← timeout', () async {
    await db.setSetting('api_token', 't');
    final api = ApiClient(
      baseUrl: 'http://test',
      db: db,
      timeout: const Duration(milliseconds: 20),
      httpClient: MockClient((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return json({});
      }),
    );
    expect(
      () => api.quota(),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.timeout),
      ),
    );
  });
}
