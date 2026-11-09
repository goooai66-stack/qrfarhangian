import 'dart:io';

import 'package:calorie_lens/core/recognition/food_recognizer.dart';
import 'package:calorie_lens/data/db/app_database.dart';
import 'package:calorie_lens/data/scan/pending_scan_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PendingScanRepository repo;
  late FakeFoodRecognizer recognizer;
  late PendingScanProcessor processor;
  final photos = <String, List<int>>{};

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PendingScanRepository(db);
    recognizer = FakeFoodRecognizer();
    photos
      ..clear()
      ..['/p1.jpg'] = [1]
      ..['/p2.jpg'] = [2];
    processor = PendingScanProcessor(
      repo: repo,
      recognizer: recognizer,
      readPhoto: (p) async => photos[p],
    );
  });
  tearDown(() => db.close());

  Future<int> enqueue(String path) =>
      repo.enqueue(photoPath: path, meal: MealType.lunch, dayKey: '2026-11-09');

  test('اتصال برقرار ← نتیجه ذخیره و آماده‌ی بررسی', () async {
    final id = await enqueue('/p1.jpg');
    expect(await processor.processAll(), 1);
    final s = (await repo.byId(id))!;
    expect(s.status, PendingScanStatus.done);
    expect(s.mealType, MealType.lunch);
    final r = PendingScanRepository.resultOf(s)!;
    expect(r.items.first.foodId, 'chelo');
  });

  test('هنوز آفلاین ← در صف می‌ماند و تلاش شمرده نمی‌شود', () async {
    final id = await enqueue('/p1.jpg');
    await enqueue('/p2.jpg');
    recognizer.error = RecognitionException(ApiErrorKind.offline);
    expect(await processor.processAll(), 0);
    expect(recognizer.calls, 1); // بعد از اولین آفلاین متوقف شد
    final s = (await repo.byId(id))!;
    expect(s.status, PendingScanStatus.queued);
    expect(s.attempts, 0);
  });

  test('خطای دیگر ← بعد از ۳ تلاش failed', () async {
    final id = await enqueue('/p1.jpg');
    recognizer.error = RecognitionException(ApiErrorKind.busy);
    for (var i = 0; i < 3; i++) {
      await processor.processAll();
    }
    final s = (await repo.byId(id))!;
    expect(s.status, PendingScanStatus.failed);
    expect(s.attempts, 3);
    expect(await repo.queued(), isEmpty);
  });

  test('عکس پاک شده ← از صف حذف', () async {
    final id = await enqueue('/missing.jpg');
    await processor.processAll();
    expect(await repo.byId(id), isNull);
  });

  test('مهاجرت v2 ← v3: ستون‌های جدید صف', () async {
    await db.close();
    final dir = Directory.systemTemp.createTempSync('cl_mig3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final fresh = AppDatabase(NativeDatabase(file));
    await fresh.customSelect('SELECT 1').get();
    await fresh.close();
    var done = false;
    db = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          if (done) return;
          done = true;
          raw.execute('DROP TABLE pending_scans');
          // طرح دقیق نسخه‌ی ۱ و ۲ (تغییری نکرده بود).
          raw.execute(
            'CREATE TABLE "pending_scans" ("id" INTEGER NOT NULL PRIMARY KEY '
            'AUTOINCREMENT, "photo_path" TEXT NOT NULL, "created_at" INTEGER '
            'NOT NULL, "status" TEXT NOT NULL)',
          );
          raw.execute(
            "INSERT INTO pending_scans (photo_path, created_at, status) "
            "VALUES ('/old.jpg', 0, 'queued')",
          );
          raw.execute('PRAGMA user_version = 2');
        },
      ),
    );
    repo = PendingScanRepository(db);
    final old = (await repo.queued()).single;
    expect(old.photoPath, '/old.jpg');
    expect(old.attempts, 0);
    expect(old.mealType, isNull);
    await enqueue('/new.jpg');
    expect(await repo.queued(), hasLength(2));
  });
}
