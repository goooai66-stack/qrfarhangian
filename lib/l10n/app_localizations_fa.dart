// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'کالری‌لنز';

  @override
  String get tabToday => 'امروز';

  @override
  String get tabProgress => 'پیشرفت';

  @override
  String get tabPlans => 'برنامه‌ها';

  @override
  String get tabProfile => 'پروفایل';

  @override
  String get todayPlaceholder => 'داشبورد روزانه در مرحله‌ی ۲ ساخته می‌شود.';

  @override
  String get progressPlaceholder =>
      'ثبت وزن و نمودارها در مرحله‌ی ۴ ساخته می‌شود.';

  @override
  String get plansPlaceholder =>
      'برنامه‌ها و چالش‌ها در نسخه‌های بعدی می‌آیند.';

  @override
  String get profilePlaceholder =>
      'پروفایل و تنظیمات در مرحله‌ی ۱ ساخته می‌شود.';

  @override
  String get comingSoon => 'به‌زودی';

  @override
  String get themeMode => 'حالت نمایش';

  @override
  String get themeSystem => 'مطابق سیستم';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeDark => 'تیره';

  @override
  String get logFood => 'ثبت غذا';

  @override
  String get medicalDisclaimer =>
      'این اپ جایگزین پزشک یا متخصص تغذیه نیست. اعداد تخمینی‌اند.';

  @override
  String todayDate(String date) {
    return 'امروز: $date';
  }
}
