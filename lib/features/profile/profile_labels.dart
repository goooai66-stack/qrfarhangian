import '../../core/nutrition/nutrition_calculator.dart';
import '../../core/units/weight_unit.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';

/// برچسب‌های فارسی enumها و قالب‌بندی اعداد پروفایل.
extension ProfileLabels on AppLocalizations {
  String sexLabel(Sex s) => switch (s) {
    Sex.male => sexMale,
    Sex.female => sexFemale,
  };

  /// برای زیر ۱۸ سال «حفظ وزن» با نام «تغذیه‌ی سالم» نشان داده می‌شود.
  String goalLabel(GoalType g, {bool minor = false}) => switch (g) {
    GoalType.lose => goalLose,
    GoalType.maintain => minor ? goalHealthyEating : goalMaintain,
    GoalType.gain => goalGain,
  };

  String activityLabel(ActivityLevel a) => switch (a) {
    ActivityLevel.sedentary => actSedentary,
    ActivityLevel.light => actLight,
    ActivityLevel.moderate => actModerate,
    ActivityLevel.active => actActive,
    ActivityLevel.veryActive => actVeryActive,
  };

  String activityDesc(ActivityLevel a) => switch (a) {
    ActivityLevel.sedentary => actSedentaryDesc,
    ActivityLevel.light => actLightDesc,
    ActivityLevel.moderate => actModerateDesc,
    ActivityLevel.active => actActiveDesc,
    ActivityLevel.veryActive => actVeryActiveDesc,
  };

  String rateName(double rate) => rate <= 0.25
      ? rateSlow
      : rate <= 0.5
      ? rateNormal
      : rateFast;

  String blockReasonText(GoalBlockReason r) => switch (r) {
    GoalBlockReason.minor => goalBlockedMinor,
    GoalBlockReason.pregnancy => goalBlockedPregnancy,
    GoalBlockReason.lowBmi => goalBlockedLowBmi,
  };

  String warningText(PlanWarning w) => switch (w) {
    PlanWarning.hitSafetyFloor => warnFloor,
    PlanWarning.minorHealthyEatingOnly => warnMinor,
    PlanWarning.pregnancyNoDeficit => warnPregnancy,
    PlanWarning.lowBmiNoLoss => warnLowBmi,
    PlanWarning.consultDoctor => warnConsultDoctor,
  };

  String unitName(WeightUnit u) => switch (u) {
    WeightUnit.kg => unitKg,
    WeightUnit.lb => unitLb,
  };

  /// شکل کوتاه در جمله‌ها («۵ کیلو در هفته»).
  String unitShort(WeightUnit u) => switch (u) {
    WeightUnit.kg => unitKgShort,
    WeightUnit.lb => unitLb,
  };

  /// فقط عدد وزن در واحد انتخابی (ورودی همیشه کیلوگرم).
  String weightNumber(double kg, WeightUnit u) =>
      formatPersianNumber(u.display(kg), fractionDigits: u.fractionDigits);

  /// «۷۰٫۵ کیلوگرم» یا «۱۵۵ پوند».
  String weight(double kg, WeightUnit u) =>
      kgValue(weightNumber(kg, u), unitName(u));
  String cm(double v) => cmValue(formatPersianNumber(v));
  String grams(double v) => gramsValue(formatPersianNumber(v));

  /// سرعت هفتگی؛ [kg] کیلوگرم در هفته.
  String rate(double kg, WeightUnit u) => rateValue(
    formatPersianNumber(
      u.fromKg(kg),
      fractionDigits: u == WeightUnit.kg ? 2 : 1,
    ),
    unitShort(u),
  );
}
