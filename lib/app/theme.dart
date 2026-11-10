import 'package:flutter/material.dart';

/// رنگ‌های برند (بخش ۵-۳): سبز تازه + نارنجی گرم.
abstract final class BrandColors {
  static const green = Color(0xFF2EAD5B);
  static const orange = Color(0xFFF08A24);

  /// نارنجی پررنگ برای زمینه‌ی متن/آیکون سفید (کنتراست ≥ ۴٫۵، WCAG AA).
  /// نارنجی روشن فقط برای تزئین بدون متن روی آن.
  static const orangeDeep = Color(0xFFB85C00);

  /// سبزهای پررنگ برای زمینه‌ی متن سفید (کارت اشتراک).
  static const greenDeep = Color(0xFF1E7A40);
  static const greenDarker = Color(0xFF145A2E);
}

const _fontFamily = 'Vazirmatn';

ThemeData _build(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.green,
    brightness: brightness,
  ).copyWith(secondary: BrandColors.orange, tertiary: BrandColors.orange);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _fontFamily,
    brightness: brightness,
  );

  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BrandColors.orangeDeep,
      foregroundColor: Colors.white,
      extendedTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontFamily: _fontFamily, fontSize: 13),
      ),
    ),
  );
}

final lightTheme = _build(Brightness.light);
final darkTheme = _build(Brightness.dark);
