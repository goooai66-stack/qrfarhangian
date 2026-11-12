import '../../core/nutrition/nutrition_types.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';

/// برچسب وعده‌ها، واحدها و قالب اعداد تغذیه‌ای.
extension LoggingLabels on AppLocalizations {
  /// در حالت رمضان صبحانه «سحر» و شام «افطار» نامیده می‌شود.
  String mealLabel(MealType m, {bool ramadan = false}) => switch (m) {
    MealType.breakfast => ramadan ? mealSuhoor : mealBreakfast,
    MealType.lunch => mealLunch,
    MealType.dinner => ramadan ? mealIftar : mealDinner,
    MealType.snack => mealSnack,
  };

  /// نام واحد از ترجمه؛ اگر کد ناشناخته بود، نام داخل داده.
  String unitLabel(String code, {String? fallback}) => switch (code) {
    'kafgir' => uKafgir,
    'ladle' => uLadle,
    'plate' => uPlate,
    'bowl' => uBowl,
    'glass' => uGlass,
    'tablespoon' => uTablespoon,
    'palm' => uPalm,
    'piece' => uPiece,
    'gram' => uGram,
    'slice' => uSlice,
    _ => fallback ?? code,
  };

  /// «۱٫۵ کفگیر»
  String quantityLabel(double q, String unit, {String? fallback}) =>
      '${formatPersianNumber(q, fractionDigits: 2)} '
      '${unitLabel(unit, fallback: fallback)}';

  /// «۲۵۰ کالری» یا «—» اگر نامعلوم.
  String kcalOrDash(double? kcal) =>
      kcal == null ? noValue : kcalValue(formatPersianNumber(kcal));
}
