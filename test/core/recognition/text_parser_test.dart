import 'dart:convert';

import 'package:calorie_lens/core/recognition/food_recognizer.dart';
import 'package:calorie_lens/core/recognition/text_parser.dart';
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

  CloudTextParser parser(http.Response Function(http.Request) onVoice) =>
      CloudTextParser(
        ApiClient(
          baseUrl: 'http://test/',
          db: db,
          httpClient: MockClient((req) async {
            if (req.url.path == '/auth/device') return json({'token': 't'});
            return onVoice(req);
          }),
        ),
      );

  test('جمله به سرور می‌رود و نتیجه مثل اسکن خوانده می‌شود', () async {
    late String sent;
    final r = await parser((req) {
      sent = (jsonDecode(req.body) as Map)['text'] as String;
      return json({
        'is_food': true,
        'meal': 'dinner',
        'items': [
          {
            'food_id': null,
            'name_fa': 'کوکو سبزی',
            'quantity': 2,
            'unit': 'piece',
            'confidence': 0.7,
          },
        ],
      });
    }).parse('دو تا کوکو سبزی خوردم');
    expect(sent, 'دو تا کوکو سبزی خوردم');
    expect(r.isFood, isTrue);
    expect(r.meal, MealType.dinner);
    expect(r.items.single.foodId, isNull); // عدد ساختگی نمی‌سازد
    expect(r.items.single.quantity, 2);
  });

  test('سهمیه‌ی صوتی تمام: خطای قابل‌فهم', () async {
    final p = parser(
      (_) => json({
        'error': {'code': 'voice_quota_exceeded'},
      }, 429),
    );
    await expectLater(
      p.parse('یک لیوان دوغ'),
      throwsA(
        isA<RecognitionException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.voiceQuotaExceeded,
        ),
      ),
    );
  });

  test('پاسخ خراب سرور: خطای server، نه کرش', () async {
    final p = parser(
      (_) => json({
        'is_food': true,
        'items': [
          {'name_fa': 'x'},
        ],
      }),
    );
    await expectLater(
      p.parse('چیزی'),
      throwsA(
        isA<RecognitionException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.server,
        ),
      ),
    );
  });
}
