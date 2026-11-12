import 'package:drift/drift.dart';

import '../../core/nutrition/serving.dart';
import '../../core/utils/jalali_date.dart';
import '../db/app_database.dart';

/// وزن، آمار روزانه، روزهای ثبت‌شده و آب (برای تب «پیشرفت»).
class ProgressRepository {
  ProgressRepository(this._db);

  final AppDatabase _db;

  // ---- وزن ----

  Stream<List<WeightLog>> watchWeights() =>
      (_db.select(_db.weightLogs)..orderBy([
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch();

  /// برای هر روز حداکثر یک ثبت وزن (آخری می‌ماند).
  Future<void> setWeight(DateTime day, double kg) => _db.transaction(() async {
    final key = dayKey(day);
    await (_db.delete(_db.weightLogs)..where((t) => t.date.equals(key))).go();
    await _db
        .into(_db.weightLogs)
        .insert(WeightLogsCompanion.insert(date: key, weightKg: kg));
  });

  Future<void> deleteWeight(int id) =>
      (_db.delete(_db.weightLogs)..where((t) => t.id.equals(id))).go();

  // ---- غذا ----

  /// جمع روزانه در بازه‌ی [from] تا [to] (هر دو شامل). روزهای بدون ثبت در نقشه نیستند.
  Stream<Map<String, DayTotals>> watchDailyTotals(DateTime from, DateTime to) {
    final a = dayKey(from), b = dayKey(to);
    final q = _db.select(_db.foodLogs)
      ..where((t) => t.date.isBetweenValues(a, b));
    return q.watch().map((logs) {
      final byDay = <String, List<Nutrients>>{};
      for (final l in logs) {
        byDay
            .putIfAbsent(l.date, () => [])
            .add(
              Nutrients(
                kcal: l.kcal,
                protein: l.protein,
                carbs: l.carbs,
                fat: l.fat,
              ),
            );
      }
      return {for (final e in byDay.entries) e.key: DayTotals.sum(e.value)};
    });
  }

  /// همه‌ی روزهایی که حداقل یک غذا ثبت شده.
  Stream<Set<String>> watchLoggedDays() {
    final q = _db.selectOnly(_db.foodLogs, distinct: true)
      ..addColumns([_db.foodLogs.date]);
    return q.watch().map(
      (rows) => {for (final r in rows) r.read(_db.foodLogs.date)!},
    );
  }

  Stream<int> watchMaxWaterGlasses() {
    final m = _db.waterLogs.glasses.max();
    final q = _db.selectOnly(_db.waterLogs)..addColumns([m]);
    return q.watchSingle().map((r) => r.read(m) ?? 0);
  }
}
