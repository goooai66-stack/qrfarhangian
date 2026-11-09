import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ads/ad_service.dart';
import 'config.dart';
import '../core/billing/billing_service.dart';
import '../core/recognition/food_recognizer.dart';
import '../core/utils/jalali_date.dart';
import '../data/api/api_client.dart';
import '../data/db/app_database.dart';
import '../data/foods/food_repository.dart';
import '../data/logs/food_log_repository.dart';
import '../data/scan/pending_scan_repository.dart';
import '../data/scan/photo_store.dart';
import '../features/scan/photo_source.dart';
import '../features/scan/scan_service.dart';
import '../data/profile/profile_repository.dart';

/// دیتابیس محلی. در main با نمونه‌ی واقعی override می‌شود؛ در تست با حافظه.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// تا مرحله‌ی ۳ و ۵ پیاده‌سازی‌های Fake استفاده می‌شوند.
final adServiceProvider = Provider<AdService>((ref) => FakeAdService());
final billingServiceProvider = Provider<BillingService>(
  (ref) => FakeBillingService(),
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
