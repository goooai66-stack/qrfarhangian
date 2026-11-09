import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ads/ad_service.dart';
import 'config.dart';
import 'flavor.dart';
import '../core/billing/billing_service.dart';
import '../core/nutrition/serving.dart';
import '../core/platform/home_widget_service.dart';
import '../core/platform/share_service.dart';
import '../core/platform/store_rating.dart';
import '../core/progress/badges.dart';
import '../core/progress/streak.dart';
import '../core/reminders/reminder_plan.dart';
import '../core/reminders/reminder_scheduler.dart';
import '../core/utils/persian_digits.dart';
import '../core/recognition/food_recognizer.dart';
import '../core/utils/jalali_date.dart';
import '../data/api/api_client.dart';
import '../data/db/app_database.dart';
import '../data/foods/food_repository.dart';
import '../data/logs/food_log_repository.dart';
import '../data/monetization/monetization.dart';
import '../features/monetization/ad_coordinator.dart';
import '../data/progress/progress_repository.dart';
import '../data/scan/pending_scan_repository.dart';
import '../data/scan/photo_store.dart';
import '../features/scan/photo_source.dart';
import '../features/scan/scan_service.dart';
import '../l10n/app_localizations.dart';
import '../data/profile/profile_repository.dart';

/// دیتابیس محلی. در main با نمونه‌ی واقعی override می‌شود؛ در تست با حافظه.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// تا مرحله‌ی ۳ و ۵ پیاده‌سازی‌های Fake استفاده می‌شوند.
/// تا وقتی SDK تپسل و کلیدش اضافه نشده: debug ← تبلیغ نمونه، release ← بدون تبلیغ.
final adServiceProvider = Provider<AdService>(
  (ref) => kDebugMode ? FakeAdService(placeholders: true) : const NoAdService(),
);

String get _storeId => currentStore == Store.myket ? 'myket' : 'bazaar';

/// تا وقتی Poolakey/Myket Billing اضافه نشده: debug ← خرید آزمایشی
/// (توکن test- که سرور توسعه می‌پذیرد)، release ← «پرداخت فعال نیست».
final billingServiceProvider = Provider<BillingService>(
  (ref) => kDebugMode
      ? FakeBillingService(storeId: _storeId)
      : UnavailableBillingService(_storeId),
);
final apiClientProvider = Provider<ApiClient>(
  (ref) =>
      ApiClient(baseUrl: AppConfig.apiBaseUrl, db: ref.watch(databaseProvider)),
);

/// تشخیص غذا: ابری از طریق سرور واسط؛ یا جعلی با `FAKE_SCAN=true`.
final foodRecognizerProvider = Provider<FoodRecognizer>(
  (ref) => AppConfig.fakeScan
      ? FakeFoodRecognizer(delay: const Duration(seconds: 2))
      : CloudRecognizer(ref.watch(apiClientProvider)),
);

const _themeKey = 'theme_mode';

/// حالت تم (سیستم/روشن/تیره)، ذخیره‌شده در جدول تنظیمات.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final v = await ref.read(databaseProvider).getSetting(_themeKey);
    final mode = ThemeMode.values.where((m) => m.name == v).firstOrNull;
    if (mode != null && ref.mounted) state = mode;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(databaseProvider).setSetting(_themeKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ---- پروفایل و آنبوردینگ ----

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(databaseProvider)),
);

/// مقدار اولیه در main از دیتابیس خوانده و override می‌شود.
final initialOnboardingDoneProvider = Provider<bool>((ref) => false);

/// آیا آنبوردینگ کامل شده است؟ (= پروفایل ذخیره شده)
class OnboardingDoneNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(initialOnboardingDoneProvider);

  void markDone() => state = true;
}

final onboardingDoneProvider = NotifierProvider<OnboardingDoneNotifier, bool>(
  OnboardingDoneNotifier.new,
);

final profileProvider = StreamProvider<UserProfile?>(
  (ref) => ref.watch(profileRepositoryProvider).watchProfile(),
);

final activeGoalProvider = StreamProvider<Goal?>(
  (ref) => ref.watch(profileRepositoryProvider).watchActiveGoal(),
);

final currentWeightProvider = StreamProvider<double?>(
  (ref) => ref.watch(profileRepositoryProvider).watchCurrentWeight(),
);

// ---- پایگاه غذا و ثبت غذا (مرحله‌ی ۲) ----

/// پایگاه غذا از assets؛ یک‌بار بارگذاری و نگه‌داری می‌شود.
final foodRepositoryProvider = FutureProvider<FoodRepository>(
  (ref) => FoodRepository.loadFromAssets(),
);

final foodLogRepositoryProvider = Provider<FoodLogRepository>(
  (ref) => FoodLogRepository(ref.watch(databaseProvider)),
);

/// روز انتخاب‌شده در داشبورد (فقط تاریخ، ساعت ۰۰:۰۰ محلی).
class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void select(DateTime day) {
    final d = dateOnly(day);
    // روز آینده انتخاب نمی‌شود.
    state = d.isAfter(dateOnly(DateTime.now())) ? dateOnly(DateTime.now()) : d;
  }

  void today() => state = dateOnly(DateTime.now());
}

final selectedDayProvider = NotifierProvider<SelectedDayNotifier, DateTime>(
  SelectedDayNotifier.new,
);

final dayLogsProvider = StreamProvider.family<List<FoodLog>, DateTime>(
  (ref, day) => ref.watch(foodLogRepositoryProvider).watchDay(dayKey(day)),
);

final goalOnProvider = StreamProvider.family<Goal?, DateTime>(
  (ref, day) => ref.watch(profileRepositoryProvider).watchGoalOn(day),
);

final waterProvider = StreamProvider.family<int, DateTime>(
  (ref, day) => ref.watch(foodLogRepositoryProvider).watchWater(dayKey(day)),
);

final foodFrequencyProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(foodLogRepositoryProvider).watchFrequency(),
);

final recentFoodIdsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(foodLogRepositoryProvider).watchRecentFoodIds(),
);

final favoriteFoodIdsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(foodLogRepositoryProvider).watchFavorites(),
);

// ---- اسکن عکس (مرحله‌ی ۳) ----

final photoStoreProvider = Provider<PhotoStore>((ref) => PhotoStore());

final photoSourceProvider = Provider<PhotoSource>(
  (ref) => ImagePickerPhotoSource(),
);

final pendingScanRepositoryProvider = Provider<PendingScanRepository>(
  (ref) => PendingScanRepository(ref.watch(databaseProvider)),
);

final pendingScansProvider = StreamProvider<List<PendingScan>>(
  (ref) => ref.watch(pendingScanRepositoryProvider).watchAll(),
);

final pendingScanProcessorProvider = Provider<PendingScanProcessor>(
  (ref) => PendingScanProcessor(
    repo: ref.watch(pendingScanRepositoryProvider),
    recognizer: ref.watch(foodRecognizerProvider),
    readPhoto: ref.watch(photoStoreProvider).read,
  ),
);

final scanServiceProvider = Provider<ScanService>(
  (ref) => ScanService(
    recognizer: ref.watch(foodRecognizerProvider),
    photos: ref.watch(photoStoreProvider),
    pending: ref.watch(pendingScanRepositoryProvider),
  ),
);

// ---- پیشرفت، یادآورها و نگه‌داشت (مرحله‌ی ۴) ----

/// «امروز» (فقط تاریخ)؛ با refresh بعد از نیمه‌شب جلو می‌رود.
class TodayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void refresh() {
    final now = dateOnly(DateTime.now());
    if (now != state) state = now;
  }
}

final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(databaseProvider)),
);

final weightsProvider = StreamProvider<List<WeightLog>>(
  (ref) => ref.watch(progressRepositoryProvider).watchWeights(),
);

final loggedDaysProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(progressRepositoryProvider).watchLoggedDays(),
);

final maxWaterProvider = StreamProvider<int>(
  (ref) => ref.watch(progressRepositoryProvider).watchMaxWaterGlasses(),
);

/// جمع روزانه‌ی [days] روز اخیر تا امروز.
final dailyTotalsProvider = StreamProvider.family<Map<String, DayTotals>, int>((
  ref,
  days,
) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(progressRepositoryProvider)
      .watchDailyTotals(
        DateTime(today.year, today.month, today.day - days + 1),
        today,
      );
});

final streakProvider = Provider<({int current, int longest})>((ref) {
  final days = ref.watch(loggedDaysProvider).value ?? const <String>{};
  return (
    current: currentStreak(days, ref.watch(todayProvider)),
    longest: longestStreak(days),
  );
});

final badgesProvider = Provider<Set<Achievement>>((ref) {
  final profile = ref.watch(profileProvider).value;
  final days = ref.watch(loggedDaysProvider).value ?? const <String>{};
  return earnedBadges(
    BadgeInputs(
      loggedDays: days.length,
      longestStreak: ref.watch(streakProvider).longest,
      goalType: profile?.goalType,
      startWeightKg: profile?.startWeightKg,
      weightsKg: [
        for (final w in ref.watch(weightsProvider).value ?? const <WeightLog>[])
          w.weightKg,
      ],
      maxWaterGlasses: ref.watch(maxWaterProvider).value ?? 0,
    ),
  );
});

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalReminderScheduler(),
);

const _remindersKey = 'reminders';

/// تنظیمات یادآور، ذخیره در دیتابیس. زمان‌بندی در صفحه‌ی تنظیمات اعمال می‌شود.
class ReminderSettingsNotifier extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() async => ReminderSettings.decode(
    await ref.read(databaseProvider).getSetting(_remindersKey),
  );

  Future<void> save(ReminderSettings s) async {
    state = AsyncData(s);
    await ref.read(databaseProvider).setSetting(_remindersKey, s.encode());
  }
}

final reminderSettingsProvider =
    AsyncNotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => AndroidHomeWidgetService(),
);
final shareServiceProvider = Provider<ShareService>(
  (ref) => SystemShareService(),
);
final storeRatingProvider = Provider<StoreRating>(
  (ref) => ChannelStoreRating(),
);

/// عکس قبل یا بعد: مسیر محلی، تاریخ و وزن همان روز.
typedef ProgressPhoto = ({String path, DateTime date, double? weightKg});

const _beforeAfterKey = 'before_after';

class BeforeAfterNotifier
    extends AsyncNotifier<({ProgressPhoto? before, ProgressPhoto? after})> {
  @override
  Future<({ProgressPhoto? before, ProgressPhoto? after})> build() async {
    final raw = await ref.read(databaseProvider).getSetting(_beforeAfterKey);
    if (raw == null) return (before: null, after: null);
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      ProgressPhoto? p(String k) {
        final m = (j[k] as Map?)?.cast<String, dynamic>();
        if (m == null) return null;
        return (
          path: m['path'] as String,
          date: DateTime.parse(m['date'] as String),
          weightKg: (m['kg'] as num?)?.toDouble(),
        );
      }

      return (before: p('before'), after: p('after'));
    } catch (_) {
      return (before: null, after: null);
    }
  }

  Future<void> set({required bool before, ProgressPhoto? photo}) async {
    final cur = state.value ?? (before: null, after: null);
    final next = before
        ? (before: photo, after: cur.after)
        : (before: cur.before, after: photo);
    state = AsyncData(next);
    Map<String, Object?>? enc(ProgressPhoto? p) => p == null
        ? null
        : {'path': p.path, 'date': p.date.toIso8601String(), 'kg': p.weightKg};
    await ref
        .read(databaseProvider)
        .setSetting(
          _beforeAfterKey,
          jsonEncode({'before': enc(next.before), 'after': enc(next.after)}),
        );
  }
}

final beforeAfterProvider =
    AsyncNotifierProvider<
      BeforeAfterNotifier,
      ({ProgressPhoto? before, ProgressPhoto? after})
    >(BeforeAfterNotifier.new);

/// داده‌ی ویجت صفحه‌ی اصلی برای امروز (null تا هدف معلوم نیست).
final widgetSnapshotProvider = Provider<WidgetSnapshot?>((ref) {
  final today = ref.watch(todayProvider);
  final goal = ref.watch(goalOnProvider(today)).value;
  final logs = ref.watch(dayLogsProvider(today)).value;
  if (goal == null || logs == null) return null;
  final t = lookupAppLocalizations(const Locale('fa'));
  final consumed = logs.fold<double>(0, (s, l) => s + (l.kcal ?? 0)).round();
  final remaining = goal.kcal - consumed;
  return WidgetSnapshot(
    value: formatPersianNumber(remaining.abs()),
    label: remaining >= 0 ? t.widgetRemaining : t.widgetOver,
    detail: t.widgetDetail(
      formatPersianNumber(consumed),
      formatPersianNumber(goal.kcal),
    ),
  );
});

// ---- درآمد: تبلیغات، اشتراک، سهمیه (مرحله‌ی ۵) ----

/// ساعت (در تست جابه‌جا می‌شود).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final monetizationApiProvider = Provider<MonetizationApi>(
  (ref) => ServerMonetizationApi(ref.watch(apiClientProvider)),
);

/// وضعیت ویژه و سهمیه. اول از کش محلی (آفلاین)، بعد از سرور.
class EntitlementNotifier extends AsyncNotifier<QuotaStatus> {
  PremiumCache get _cache => PremiumCache(ref.read(databaseProvider));

  @override
  Future<QuotaStatus> build() async {
    final until = await _cache.read();
    final now = ref.read(clockProvider)();
    Future.microtask(refresh);
    return until != null && until.isAfter(now)
        ? QuotaStatus(premium: true, premiumUntil: until)
        : QuotaStatus.free;
  }

  /// از سرور؛ خطای شبکه نادیده گرفته می‌شود (کش می‌ماند).
  Future<void> refresh() async {
    try {
      apply(await ref.read(monetizationApiProvider).quota());
    } catch (_) {}
  }

  void apply(QuotaStatus q) {
    state = AsyncData(q);
    _cache.write(q.premium ? q.premiumUntil : null);
  }
}

final entitlementProvider =
    AsyncNotifierProvider<EntitlementNotifier, QuotaStatus>(
      EntitlementNotifier.new,
    );

final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(entitlementProvider).value?.premium ?? false,
);

final adCoordinatorProvider = Provider<AdCoordinator>(
  (ref) => AdCoordinator(ref),
);
