import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fa')];

  /// نام اپ (موقت)
  ///
  /// In fa, this message translates to:
  /// **'کالری‌لنز'**
  String get appTitle;

  /// No description provided for @tabToday.
  ///
  /// In fa, this message translates to:
  /// **'امروز'**
  String get tabToday;

  /// No description provided for @tabProgress.
  ///
  /// In fa, this message translates to:
  /// **'پیشرفت'**
  String get tabProgress;

  /// No description provided for @tabPlans.
  ///
  /// In fa, this message translates to:
  /// **'برنامه‌ها'**
  String get tabPlans;

  /// No description provided for @tabProfile.
  ///
  /// In fa, this message translates to:
  /// **'پروفایل'**
  String get tabProfile;

  /// No description provided for @todayPlaceholder.
  ///
  /// In fa, this message translates to:
  /// **'داشبورد روزانه در مرحله‌ی ۲ ساخته می‌شود.'**
  String get todayPlaceholder;

  /// No description provided for @progressPlaceholder.
  ///
  /// In fa, this message translates to:
  /// **'ثبت وزن و نمودارها در مرحله‌ی ۴ ساخته می‌شود.'**
  String get progressPlaceholder;

  /// No description provided for @plansPlaceholder.
  ///
  /// In fa, this message translates to:
  /// **'برنامه‌ها و چالش‌ها در نسخه‌های بعدی می‌آیند.'**
  String get plansPlaceholder;

  /// No description provided for @comingSoon.
  ///
  /// In fa, this message translates to:
  /// **'به‌زودی'**
  String get comingSoon;

  /// No description provided for @themeMode.
  ///
  /// In fa, this message translates to:
  /// **'حالت نمایش'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In fa, this message translates to:
  /// **'مطابق سیستم'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In fa, this message translates to:
  /// **'روشن'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fa, this message translates to:
  /// **'تیره'**
  String get themeDark;

  /// No description provided for @logFood.
  ///
  /// In fa, this message translates to:
  /// **'ثبت غذا'**
  String get logFood;

  /// سلب مسئولیت پزشکی — بخش ۶-۵؛ هرگز حذف نشود
  ///
  /// In fa, this message translates to:
  /// **'این اپ جایگزین پزشک یا متخصص تغذیه نیست. اعداد تخمینی‌اند.'**
  String get medicalDisclaimer;

  /// No description provided for @todayDate.
  ///
  /// In fa, this message translates to:
  /// **'امروز: {date}'**
  String todayDate(String date);

  /// No description provided for @next.
  ///
  /// In fa, this message translates to:
  /// **'بعدی'**
  String get next;

  /// No description provided for @back.
  ///
  /// In fa, this message translates to:
  /// **'قبلی'**
  String get back;

  /// No description provided for @save.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره شد'**
  String get saved;

  /// No description provided for @cancel.
  ///
  /// In fa, this message translates to:
  /// **'انصراف'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In fa, this message translates to:
  /// **'تأیید'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In fa, this message translates to:
  /// **'بله'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In fa, this message translates to:
  /// **'خیر'**
  String get no;

  /// No description provided for @stepOf.
  ///
  /// In fa, this message translates to:
  /// **'{current} از {total}'**
  String stepOf(String current, String total);

  /// No description provided for @qSex.
  ///
  /// In fa, this message translates to:
  /// **'جنسیتت چیست؟'**
  String get qSex;

  /// No description provided for @sexMale.
  ///
  /// In fa, this message translates to:
  /// **'مرد'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In fa, this message translates to:
  /// **'زن'**
  String get sexFemale;

  /// No description provided for @qBirthDate.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ تولدت؟'**
  String get qBirthDate;

  /// No description provided for @ageYears.
  ///
  /// In fa, this message translates to:
  /// **'{age} سال'**
  String ageYears(String age);

  /// No description provided for @dateDay.
  ///
  /// In fa, this message translates to:
  /// **'روز'**
  String get dateDay;

  /// No description provided for @dateMonth.
  ///
  /// In fa, this message translates to:
  /// **'ماه'**
  String get dateMonth;

  /// No description provided for @dateYear.
  ///
  /// In fa, this message translates to:
  /// **'سال'**
  String get dateYear;

  /// No description provided for @qPregnancy.
  ///
  /// In fa, this message translates to:
  /// **'باردار هستی یا به نوزاد شیر می‌دهی؟'**
  String get qPregnancy;

  /// No description provided for @pregnancyHint.
  ///
  /// In fa, this message translates to:
  /// **'در این دوران، کم کردن کالری فقط با نظر پزشک توصیه می‌شود.'**
  String get pregnancyHint;

  /// No description provided for @qHeight.
  ///
  /// In fa, this message translates to:
  /// **'قدت چقدر است؟'**
  String get qHeight;

  /// No description provided for @unitCm.
  ///
  /// In fa, this message translates to:
  /// **'سانتی‌متر'**
  String get unitCm;

  /// No description provided for @cmValue.
  ///
  /// In fa, this message translates to:
  /// **'{value} سانتی‌متر'**
  String cmValue(String value);

  /// No description provided for @qWeight.
  ///
  /// In fa, this message translates to:
  /// **'وزن فعلی‌ات؟'**
  String get qWeight;

  /// No description provided for @unitKg.
  ///
  /// In fa, this message translates to:
  /// **'کیلوگرم'**
  String get unitKg;

  /// No description provided for @kgValue.
  ///
  /// In fa, this message translates to:
  /// **'{value} کیلوگرم'**
  String kgValue(String value);

  /// No description provided for @bmiValue.
  ///
  /// In fa, this message translates to:
  /// **'شاخص توده‌ی بدنی (BMI): {bmi}'**
  String bmiValue(String bmi);

  /// No description provided for @qGoal.
  ///
  /// In fa, this message translates to:
  /// **'هدفت چیست؟'**
  String get qGoal;

  /// No description provided for @goalLose.
  ///
  /// In fa, this message translates to:
  /// **'کاهش وزن'**
  String get goalLose;

  /// No description provided for @goalMaintain.
  ///
  /// In fa, this message translates to:
  /// **'حفظ وزن'**
  String get goalMaintain;

  /// No description provided for @goalGain.
  ///
  /// In fa, this message translates to:
  /// **'افزایش وزن'**
  String get goalGain;

  /// No description provided for @goalHealthyEating.
  ///
  /// In fa, this message translates to:
  /// **'تغذیه‌ی سالم'**
  String get goalHealthyEating;

  /// No description provided for @goalBlockedMinor.
  ///
  /// In fa, this message translates to:
  /// **'برای زیر ۱۸ سال فقط برنامه‌ی تغذیه‌ی سالم داریم. برای تغییر وزن با پزشک مشورت کن.'**
  String get goalBlockedMinor;

  /// No description provided for @goalBlockedPregnancy.
  ///
  /// In fa, this message translates to:
  /// **'در دوران بارداری و شیردهی، کاهش کالری فقط با نظر پزشک.'**
  String get goalBlockedPregnancy;

  /// No description provided for @goalBlockedLowBmi.
  ///
  /// In fa, this message translates to:
  /// **'وزنت در محدوده‌ی کم است؛ کاهش وزن برایت مناسب نیست.'**
  String get goalBlockedLowBmi;

  /// No description provided for @qGoalWeight.
  ///
  /// In fa, this message translates to:
  /// **'وزن هدفت؟'**
  String get qGoalWeight;

  /// No description provided for @goalWeightRange.
  ///
  /// In fa, this message translates to:
  /// **'بین {min} تا {max} کیلوگرم'**
  String goalWeightRange(String min, String max);

  /// No description provided for @goalWeightDiff.
  ///
  /// In fa, this message translates to:
  /// **'تغییر: {kg} کیلوگرم'**
  String goalWeightDiff(String kg);

  /// No description provided for @invalidGoalWeight.
  ///
  /// In fa, this message translates to:
  /// **'وزن هدف با هدف انتخاب‌شده جور نیست.'**
  String get invalidGoalWeight;

  /// No description provided for @qRate.
  ///
  /// In fa, this message translates to:
  /// **'با چه سرعتی؟'**
  String get qRate;

  /// No description provided for @rateSlow.
  ///
  /// In fa, this message translates to:
  /// **'آرام'**
  String get rateSlow;

  /// No description provided for @rateNormal.
  ///
  /// In fa, this message translates to:
  /// **'متعادل'**
  String get rateNormal;

  /// No description provided for @rateFast.
  ///
  /// In fa, this message translates to:
  /// **'سریع'**
  String get rateFast;

  /// No description provided for @rateValue.
  ///
  /// In fa, this message translates to:
  /// **'{kg} کیلو در هفته'**
  String rateValue(String kg);

  /// No description provided for @rateKcal.
  ///
  /// In fa, this message translates to:
  /// **'حدود {kcal} کالری در روز'**
  String rateKcal(String kcal);

  /// No description provided for @rateFloorHint.
  ///
  /// In fa, this message translates to:
  /// **'این سرعت برایت زیاد است؛ کالری روی حداقل ایمن می‌ماند.'**
  String get rateFloorHint;

  /// No description provided for @qActivity.
  ///
  /// In fa, this message translates to:
  /// **'روزهایت چقدر پرتحرک است؟'**
  String get qActivity;

  /// No description provided for @actSedentary.
  ///
  /// In fa, this message translates to:
  /// **'بی‌تحرک'**
  String get actSedentary;

  /// No description provided for @actSedentaryDesc.
  ///
  /// In fa, this message translates to:
  /// **'بیشتر پشت میز، بدون ورزش'**
  String get actSedentaryDesc;

  /// No description provided for @actLight.
  ///
  /// In fa, this message translates to:
  /// **'کم‌تحرک'**
  String get actLight;

  /// No description provided for @actLightDesc.
  ///
  /// In fa, this message translates to:
  /// **'۱ تا ۳ روز ورزش در هفته'**
  String get actLightDesc;

  /// No description provided for @actModerate.
  ///
  /// In fa, this message translates to:
  /// **'متوسط'**
  String get actModerate;

  /// No description provided for @actModerateDesc.
  ///
  /// In fa, this message translates to:
  /// **'۳ تا ۵ روز ورزش در هفته'**
  String get actModerateDesc;

  /// No description provided for @actActive.
  ///
  /// In fa, this message translates to:
  /// **'فعال'**
  String get actActive;

  /// No description provided for @actActiveDesc.
  ///
  /// In fa, this message translates to:
  /// **'۶ تا ۷ روز ورزش در هفته'**
  String get actActiveDesc;

  /// No description provided for @actVeryActive.
  ///
  /// In fa, this message translates to:
  /// **'خیلی فعال'**
  String get actVeryActive;

  /// No description provided for @actVeryActiveDesc.
  ///
  /// In fa, this message translates to:
  /// **'کار بدنی همراه با ورزش'**
  String get actVeryActiveDesc;

  /// No description provided for @resultTitle.
  ///
  /// In fa, this message translates to:
  /// **'برنامه‌ی شخصی تو'**
  String get resultTitle;

  /// No description provided for @resultDailyKcal.
  ///
  /// In fa, this message translates to:
  /// **'کالری روزانه‌ی تو'**
  String get resultDailyKcal;

  /// No description provided for @kcalUnit.
  ///
  /// In fa, this message translates to:
  /// **'کالری'**
  String get kcalUnit;

  /// No description provided for @macroProtein.
  ///
  /// In fa, this message translates to:
  /// **'پروتئین'**
  String get macroProtein;

  /// No description provided for @macroCarbs.
  ///
  /// In fa, this message translates to:
  /// **'کربوهیدرات'**
  String get macroCarbs;

  /// No description provided for @macroFat.
  ///
  /// In fa, this message translates to:
  /// **'چربی'**
  String get macroFat;

  /// No description provided for @gramsValue.
  ///
  /// In fa, this message translates to:
  /// **'{g} گرم'**
  String gramsValue(String g);

  /// No description provided for @resultEta.
  ///
  /// In fa, this message translates to:
  /// **'رسیدن به {weight} کیلو: حدود {date}'**
  String resultEta(String weight, String date);

  /// No description provided for @resultEtaWeeks.
  ///
  /// In fa, this message translates to:
  /// **'حدود {weeks} هفته'**
  String resultEtaWeeks(String weeks);

  /// No description provided for @resultMaintain.
  ///
  /// In fa, this message translates to:
  /// **'هدف: حفظ وزن فعلی و تغذیه‌ی سالم'**
  String get resultMaintain;

  /// No description provided for @resultChartTitle.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌بینی وزن'**
  String get resultChartTitle;

  /// No description provided for @chartWeekAxis.
  ///
  /// In fa, this message translates to:
  /// **'هفته'**
  String get chartWeekAxis;

  /// No description provided for @resultStart.
  ///
  /// In fa, this message translates to:
  /// **'شروع کن'**
  String get resultStart;

  /// No description provided for @warnFloor.
  ///
  /// In fa, this message translates to:
  /// **'برای سلامتت، سرعت کمتری انتخاب کن. کالری روزانه روی حداقل ایمن ماند.'**
  String get warnFloor;

  /// No description provided for @warnMinor.
  ///
  /// In fa, this message translates to:
  /// **'چون زیر ۱۸ سال هستی، برنامه‌ات «تغذیه‌ی سالم» است، نه کاهش وزن.'**
  String get warnMinor;

  /// No description provided for @warnPregnancy.
  ///
  /// In fa, this message translates to:
  /// **'در دوران بارداری و شیردهی کالری کم نمی‌شود.'**
  String get warnPregnancy;

  /// No description provided for @warnLowBmi.
  ///
  /// In fa, this message translates to:
  /// **'وزنت در محدوده‌ی کم است؛ برنامه روی حفظ وزن تنظیم شد.'**
  String get warnLowBmi;

  /// No description provided for @warnConsultDoctor.
  ///
  /// In fa, this message translates to:
  /// **'پیش از هر تغییر در رژیم غذایی با پزشک مشورت کن.'**
  String get warnConsultDoctor;

  /// No description provided for @profileSummary.
  ///
  /// In fa, this message translates to:
  /// **'برنامه‌ی فعلی'**
  String get profileSummary;

  /// No description provided for @profileEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش پروفایل و هدف'**
  String get profileEdit;

  /// No description provided for @profileSex.
  ///
  /// In fa, this message translates to:
  /// **'جنسیت'**
  String get profileSex;

  /// No description provided for @profileBirthDate.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ تولد'**
  String get profileBirthDate;

  /// No description provided for @profilePregnant.
  ///
  /// In fa, this message translates to:
  /// **'باردار یا شیرده'**
  String get profilePregnant;

  /// No description provided for @profileHeight.
  ///
  /// In fa, this message translates to:
  /// **'قد'**
  String get profileHeight;

  /// No description provided for @profileCurrentWeight.
  ///
  /// In fa, this message translates to:
  /// **'وزن فعلی'**
  String get profileCurrentWeight;

  /// No description provided for @profileGoal.
  ///
  /// In fa, this message translates to:
  /// **'هدف'**
  String get profileGoal;

  /// No description provided for @profileGoalWeight.
  ///
  /// In fa, this message translates to:
  /// **'وزن هدف'**
  String get profileGoalWeight;

  /// No description provided for @profileRate.
  ///
  /// In fa, this message translates to:
  /// **'سرعت'**
  String get profileRate;

  /// No description provided for @profileActivity.
  ///
  /// In fa, this message translates to:
  /// **'سطح فعالیت'**
  String get profileActivity;

  /// No description provided for @profileNoData.
  ///
  /// In fa, this message translates to:
  /// **'هنوز پروفایلی ثبت نشده است.'**
  String get profileNoData;

  /// No description provided for @editPreview.
  ///
  /// In fa, this message translates to:
  /// **'کالری روزانه با این تغییرات: {kcal}'**
  String editPreview(String kcal);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
