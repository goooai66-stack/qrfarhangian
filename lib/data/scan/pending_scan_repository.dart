import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/recognition/food_recognizer.dart';
import '../db/app_database.dart';

/// صف اسکن آفلاین (بخش ۵-۲، قدم ۸).
class PendingScanRepository {
  PendingScanRepository(this._db);

  final AppDatabase _db;

  /// حداکثر تلاش برای خطاهای غیر از «اینترنت نیست».
  static const maxAttempts = 3;

  Future<int> enqueue({
    required String photoPath,
    required MealType meal,
    required String dayKey,
  }) => _db
      .into(_db.pendingScans)
      .insert(
        PendingScansCompanion.insert(
          photoPath: photoPath,
          createdAt: DateTime.now(),
          status: PendingScanStatus.queued,
          mealType: Value(meal),
          date: Value(dayKey),
        ),
      );

  Future<List<PendingScan>> queued() =>
      (_db.select(_db.pendingScans)
            ..where((t) => t.status.equalsValue(PendingScanStatus.queued))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Stream<List<PendingScan>> watchAll() =>
      (_db.select(_db.pendingScans)
            ..where((t) => t.status.isNotValue(PendingScanStatus.failed.name))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<PendingScan?> byId(int id) => (_db.select(
    _db.pendingScans,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> markDone(int id, RecognitionResult result) =>
      (_db.update(_db.pendingScans)..where((t) => t.id.equals(id))).write(
        PendingScansCompanion(
          status: const Value(PendingScanStatus.done),
          resultJson: Value(jsonEncode(result.toJson())),
        ),
      );

  Future<void> markFailedAttempt(PendingScan s) =>
      (_db.update(_db.pendingScans)..where((t) => t.id.equals(s.id))).write(
        PendingScansCompanion(
          attempts: Value(s.attempts + 1),
          status: Value(
            s.attempts + 1 >= maxAttempts
                ? PendingScanStatus.failed
                : PendingScanStatus.queued,
          ),
        ),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.pendingScans)..where((t) => t.id.equals(id))).go();

  static RecognitionResult? resultOf(PendingScan s) => s.resultJson == null
      ? null
      : RecognitionResult.fromJson(
          (jsonDecode(s.resultJson!) as Map).cast<String, dynamic>(),
        );
}

/// پردازش صف وقتی دوباره اینترنت هست.
class PendingScanProcessor {
  PendingScanProcessor({
    required this.repo,
    required this.recognizer,
    required this.readPhoto,
  });

  final PendingScanRepository repo;
  final FoodRecognizer recognizer;
  final Future<List<int>?> Function(String path) readPhoto;
  bool _running = false;

  /// تعداد اسکن‌هایی که نتیجه گرفتند.
  Future<int> processAll() async {
    if (_running) return 0;
    _running = true;
    var done = 0;
    try {
      for (final s in await repo.queued()) {
        final bytes = await readPhoto(s.photoPath);
        if (bytes == null) {
          await repo.delete(s.id);
          continue;
        }
        try {
          await repo.markDone(s.id, await recognizer.recognize(bytes));
          done++;
        } on RecognitionException catch (e) {
          switch (e.kind) {
            // هنوز آفلاین یا سهمیه تمام: صبر کن، تلاش حساب نشود.
            case ApiErrorKind.offline ||
                ApiErrorKind.quotaExceeded ||
                ApiErrorKind.rateLimited:
              return done;
            default:
              await repo.markFailedAttempt(s);
          }
        }
      }
    } finally {
      _running = false;
    }
    return done;
  }
}
