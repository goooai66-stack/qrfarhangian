import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ads/ad_service.dart';
import '../core/billing/billing_service.dart';
import '../core/recognition/food_recognizer.dart';
import '../data/db/app_database.dart';

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
final foodRecognizerProvider = Provider<FoodRecognizer>(
  (ref) => FakeFoodRecognizer(),
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
