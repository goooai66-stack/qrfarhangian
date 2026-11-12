import 'package:drift/drift.dart';

import '../../core/nutrition/nutrition_calculator.dart';
import '../../core/utils/jalali_date.dart';
import '../db/app_database.dart';

/// خواندن و نوشتن پروفایل کاربر، هدف و وزن فعلی.
class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  /// اپ فعلاً تک‌کاربره است؛ اولین (و تنها) رکورد پروفایل.
  Future<UserProfile?> getProfile() =>
      (_db.select(_db.userProfiles)
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(1))
          .getSingleOrNull();

  Stream<UserProfile?> watchProfile() =>
      (_db.select(_db.userProfiles)
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(1))
          .watchSingleOrNull();

  Future<bool> hasProfile() async => await getProfile() != null;

  /// هدف فعال: آخرین هدفی که validFrom آن گذشته است.
  Stream<Goal?> watchActiveGoal() =>
      (_db.select(_db.goals)
            ..orderBy([
              (t) => OrderingTerm.desc(t.validFrom),
              (t) => OrderingTerm.desc(t.id),
            ])
            ..limit(1))
          .watchSingleOrNull();

  /// هدف معتبر در روز [day]: آخرین هدفی که تا پایان آن روز شروع شده؛
  /// اگر روز قبل از اولین هدف است، اولین هدف.
  Stream<Goal?> watchGoalOn(DateTime day) {
    final end = DateTime(day.year, day.month, day.day + 1);
    final q = _db.select(_db.goals)
      ..orderBy([
        (t) => OrderingTerm.desc(t.validFrom),
        (t) => OrderingTerm.desc(t.id),
      ]);
    return q.watch().map((goals) {
      for (final g in goals) {
        if (g.validFrom.isBefore(end)) return g;
      }
      return goals.isEmpty ? null : goals.last;
    });
  }

  /// وزن فعلی = آخرین ثبت وزن؛ اگر نبود، وزن شروع.
  Stream<double?> watchCurrentWeight() {
    final q = _db.select(_db.weightLogs)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(1);
    return q.watchSingleOrNull().asyncMap(
      (w) async => w?.weightKg ?? (await getProfile())?.startWeightKg,
    );
  }

  /// پایان آنبوردینگ: پروفایل + هدف + اولین ثبت وزن، در یک تراکنش.
  Future<void> saveOnboarding(NutritionInput input, NutritionPlan plan) =>
      _db.transaction(() async {
        final now = DateTime.now();
        await _db.delete(_db.userProfiles).go();
        await _db
            .into(_db.userProfiles)
            .insert(
              _companion(input, plan, startWeight: input.weightKg, now: now),
            );
        await _insertGoal(plan, now);
        await _upsertWeight(input.weightKg, now);
      });

  /// ویرایش پروفایل و هدف ← محاسبه‌ی دوباره و هدف جدید در تاریخچه.
  Future<void> updateProfile(NutritionInput input, NutritionPlan plan) =>
      _db.transaction(() async {
        final now = DateTime.now();
        final existing = await getProfile();
        if (existing == null) {
          await _db
              .into(_db.userProfiles)
              .insert(
                _companion(input, plan, startWeight: input.weightKg, now: now),
              );
        } else {
          await (_db.update(
            _db.userProfiles,
          )..where((t) => t.id.equals(existing.id))).write(
            _companion(
              input,
              plan,
              startWeight: existing.startWeightKg,
              now: existing.createdAt,
            ),
          );
        }
        await _insertGoal(plan, now);
        await _upsertWeight(input.weightKg, now);
      });

  UserProfilesCompanion _companion(
    NutritionInput input,
    NutritionPlan plan, {
    required double startWeight,
    required DateTime now,
  }) => UserProfilesCompanion.insert(
    sex: input.sex,
    birthDate: input.birthDate,
    heightCm: input.heightCm,
    startWeightKg: startWeight,
    goalWeightKg: input.goalWeightKg,
    activityLevel: input.activityLevel,
    // هدفِ اجراشده ذخیره می‌شود، نه هدف غیرمجاز درخواستی.
    goalType: plan.effectiveGoal,
    weeklyRateKg: input.weeklyRateKg,
    isPregnant: Value(input.sex == Sex.female && input.isPregnant),
    createdAt: now,
  );

  Future<void> _insertGoal(NutritionPlan plan, DateTime now) => _db
      .into(_db.goals)
      .insert(
        GoalsCompanion.insert(
          kcal: plan.targetKcal,
          proteinG: plan.proteinG,
          carbsG: plan.carbsG,
          fatG: plan.fatG,
          validFrom: now,
        ),
      );

  /// برای هر روز حداکثر یک ثبت وزن.
  Future<void> _upsertWeight(double kg, DateTime now) async {
    final key = dayKey(now);
    await (_db.delete(_db.weightLogs)..where((t) => t.date.equals(key))).go();
    await _db
        .into(_db.weightLogs)
        .insert(WeightLogsCompanion.insert(date: key, weightKg: kg));
  }
}

/// پروفایل ذخیره‌شده ← ورودی محاسبه.
NutritionInput inputFromProfile(UserProfile p, {double? currentWeightKg}) =>
    NutritionInput(
      sex: p.sex,
      birthDate: p.birthDate,
      heightCm: p.heightCm,
      weightKg: currentWeightKg ?? p.startWeightKg,
      goalWeightKg: p.goalWeightKg,
      activityLevel: p.activityLevel,
      goalType: p.goalType,
      weeklyRateKg: p.weeklyRateKg,
      isPregnant: p.isPregnant,
    );
