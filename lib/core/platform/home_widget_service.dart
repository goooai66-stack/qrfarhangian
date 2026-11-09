import 'package:home_widget/home_widget.dart';

/// داده‌ی ویجت صفحه‌ی اصلی (کالری باقی‌مانده). متن‌ها از قبل فارسی و
/// قالب‌بندی‌شده‌اند؛ کد بومی فقط نمایش می‌دهد.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.value,
    required this.label,
    required this.detail,
  });

  /// عدد بزرگ: «۱٬۲۳۴»
  final String value;

  /// «باقی‌مانده» یا «بیشتر از هدف»
  final String label;

  /// «۸۰۵ از ۱٬۴۰۳ کالری»
  final String detail;

  @override
  bool operator ==(Object other) =>
      other is WidgetSnapshot &&
      other.value == value &&
      other.label == label &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(value, label, detail);
}

abstract interface class HomeWidgetService {
  Future<void> update(WidgetSnapshot s);
}

class AndroidHomeWidgetService implements HomeWidgetService {
  /// همان کلاس Kotlin در android/app/src/main/kotlin/…/CalorieWidgetProvider.kt
  static const provider = 'ir.calorielens.calorie_lens.CalorieWidgetProvider';

  @override
  Future<void> update(WidgetSnapshot s) async {
    await HomeWidget.saveWidgetData<String>('value', s.value);
    await HomeWidget.saveWidgetData<String>('label', s.label);
    await HomeWidget.saveWidgetData<String>('detail', s.detail);
    await HomeWidget.updateWidget(qualifiedAndroidName: provider);
  }
}

class FakeHomeWidgetService implements HomeWidgetService {
  final updates = <WidgetSnapshot>[];

  @override
  Future<void> update(WidgetSnapshot s) async => updates.add(s);
}
