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

  /// No description provided for @unitKgShort.
  ///
  /// In fa, this message translates to:
  /// **'کیلو'**
  String get unitKgShort;

  /// No description provided for @unitLb.
  ///
  /// In fa, this message translates to:
  /// **'پوند'**
  String get unitLb;

  /// No description provided for @weightUnitTitle.
  ///
  /// In fa, this message translates to:
  /// **'واحد وزن'**
  String get weightUnitTitle;

  /// No description provided for @kgValue.
  ///
  /// In fa, this message translates to:
  /// **'{value} {unit}'**
  String kgValue(String value, String unit);

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
  /// **'بین {min} تا {max} {unit}'**
  String goalWeightRange(String min, String max, String unit);

  /// No description provided for @goalWeightDiff.
  ///
  /// In fa, this message translates to:
  /// **'تغییر: {amount} {unit}'**
  String goalWeightDiff(String amount, String unit);

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
  /// **'{amount} {unit} در هفته'**
  String rateValue(String amount, String unit);

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
  /// **'رسیدن به {weight} {unit}: حدود {date}'**
  String resultEta(String weight, String unit, String date);

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

  /// No description provided for @goToToday.
  ///
  /// In fa, this message translates to:
  /// **'برو به امروز'**
  String get goToToday;

  /// No description provided for @prevWeek.
  ///
  /// In fa, this message translates to:
  /// **'هفته‌ی قبل'**
  String get prevWeek;

  /// No description provided for @nextWeek.
  ///
  /// In fa, this message translates to:
  /// **'هفته‌ی بعد'**
  String get nextWeek;

  /// No description provided for @kcalConsumed.
  ///
  /// In fa, this message translates to:
  /// **'خورده‌شده'**
  String get kcalConsumed;

  /// No description provided for @kcalRemaining.
  ///
  /// In fa, this message translates to:
  /// **'باقی‌مانده'**
  String get kcalRemaining;

  /// No description provided for @kcalGoal.
  ///
  /// In fa, this message translates to:
  /// **'هدف'**
  String get kcalGoal;

  /// No description provided for @kcalValue.
  ///
  /// In fa, this message translates to:
  /// **'{kcal} کالری'**
  String kcalValue(String kcal);

  /// No description provided for @kcalOver.
  ///
  /// In fa, this message translates to:
  /// **'امروز {kcal} کالری بیشتر شد؛ فردا جبرانش آسان است.'**
  String kcalOver(String kcal);

  /// No description provided for @incompleteItems.
  ///
  /// In fa, this message translates to:
  /// **'{count} مورد بدون داده‌ی کامل؛ جمع‌ها تقریبی‌اند.'**
  String incompleteItems(String count);

  /// No description provided for @noGoal.
  ///
  /// In fa, this message translates to:
  /// **'هنوز هدفی تعیین نشده است.'**
  String get noGoal;

  /// No description provided for @mealBreakfast.
  ///
  /// In fa, this message translates to:
  /// **'صبحانه'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In fa, this message translates to:
  /// **'ناهار'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In fa, this message translates to:
  /// **'شام'**
  String get mealDinner;

  /// No description provided for @mealSnack.
  ///
  /// In fa, this message translates to:
  /// **'میان‌وعده'**
  String get mealSnack;

  /// No description provided for @mealEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز چیزی ثبت نشده'**
  String get mealEmpty;

  /// No description provided for @addToMeal.
  ///
  /// In fa, this message translates to:
  /// **'افزودن به {meal}'**
  String addToMeal(String meal);

  /// No description provided for @water.
  ///
  /// In fa, this message translates to:
  /// **'آب'**
  String get water;

  /// No description provided for @waterGlasses.
  ///
  /// In fa, this message translates to:
  /// **'{count} لیوان'**
  String waterGlasses(String count);

  /// No description provided for @waterAdd.
  ///
  /// In fa, this message translates to:
  /// **'یک لیوان بیشتر'**
  String get waterAdd;

  /// No description provided for @waterRemove.
  ///
  /// In fa, this message translates to:
  /// **'یک لیوان کمتر'**
  String get waterRemove;

  /// No description provided for @searchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی غذا… (مثلاً قورمه‌سبزی)'**
  String get searchHint;

  /// No description provided for @searchNoResult.
  ///
  /// In fa, this message translates to:
  /// **'غذایی با این نام پیدا نشد.'**
  String get searchNoResult;

  /// No description provided for @sectionFavorites.
  ///
  /// In fa, this message translates to:
  /// **'علاقه‌مندی‌ها'**
  String get sectionFavorites;

  /// No description provided for @sectionRecent.
  ///
  /// In fa, this message translates to:
  /// **'اخیر'**
  String get sectionRecent;

  /// No description provided for @sectionFrequent.
  ///
  /// In fa, this message translates to:
  /// **'پرتکرار'**
  String get sectionFrequent;

  /// No description provided for @sectionAll.
  ///
  /// In fa, this message translates to:
  /// **'همه‌ی غذاها'**
  String get sectionAll;

  /// No description provided for @dataIncomplete.
  ///
  /// In fa, this message translates to:
  /// **'داده ناقص'**
  String get dataIncomplete;

  /// No description provided for @dataApprox.
  ///
  /// In fa, this message translates to:
  /// **'تقریبی'**
  String get dataApprox;

  /// No description provided for @dataIncompleteHint.
  ///
  /// In fa, this message translates to:
  /// **'ارزش غذایی این غذا هنوز از منبع معتبر وارد نشده است. ثبت می‌شود، ولی در جمع کالری حساب نمی‌شود.'**
  String get dataIncompleteHint;

  /// No description provided for @unitWeightUnknown.
  ///
  /// In fa, this message translates to:
  /// **'وزن این واحد هنوز اندازه‌گیری نشده است؛ «گرم» را انتخاب کن تا عدد دقیق ببینی.'**
  String get unitWeightUnknown;

  /// No description provided for @quantity.
  ///
  /// In fa, this message translates to:
  /// **'مقدار'**
  String get quantity;

  /// No description provided for @unit.
  ///
  /// In fa, this message translates to:
  /// **'واحد'**
  String get unit;

  /// No description provided for @meal.
  ///
  /// In fa, this message translates to:
  /// **'وعده'**
  String get meal;

  /// No description provided for @logToMeal.
  ///
  /// In fa, this message translates to:
  /// **'ثبت در {meal}'**
  String logToMeal(String meal);

  /// No description provided for @logged.
  ///
  /// In fa, this message translates to:
  /// **'ثبت شد'**
  String get logged;

  /// No description provided for @deleteItem.
  ///
  /// In fa, this message translates to:
  /// **'حذف'**
  String get deleteItem;

  /// No description provided for @deleteConfirm.
  ///
  /// In fa, this message translates to:
  /// **'این مورد حذف شود؟'**
  String get deleteConfirm;

  /// No description provided for @deleted.
  ///
  /// In fa, this message translates to:
  /// **'حذف شد'**
  String get deleted;

  /// No description provided for @favoriteAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن به علاقه‌مندی‌ها'**
  String get favoriteAdd;

  /// No description provided for @favoriteRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف از علاقه‌مندی‌ها'**
  String get favoriteRemove;

  /// No description provided for @unknownFood.
  ///
  /// In fa, this message translates to:
  /// **'غذای ناشناخته'**
  String get unknownFood;

  /// No description provided for @foodNotFound.
  ///
  /// In fa, this message translates to:
  /// **'این غذا در پایگاه داده نیست؛ فقط می‌توانی حذفش کنی.'**
  String get foodNotFound;

  /// No description provided for @noValue.
  ///
  /// In fa, this message translates to:
  /// **'—'**
  String get noValue;

  /// No description provided for @enterQuantity.
  ///
  /// In fa, this message translates to:
  /// **'مقدار را وارد کن'**
  String get enterQuantity;

  /// No description provided for @increase.
  ///
  /// In fa, this message translates to:
  /// **'بیشتر'**
  String get increase;

  /// No description provided for @decrease.
  ///
  /// In fa, this message translates to:
  /// **'کمتر'**
  String get decrease;

  /// No description provided for @uKafgir.
  ///
  /// In fa, this message translates to:
  /// **'کفگیر'**
  String get uKafgir;

  /// No description provided for @uLadle.
  ///
  /// In fa, this message translates to:
  /// **'ملاقه'**
  String get uLadle;

  /// No description provided for @uPlate.
  ///
  /// In fa, this message translates to:
  /// **'بشقاب'**
  String get uPlate;

  /// No description provided for @uBowl.
  ///
  /// In fa, this message translates to:
  /// **'کاسه'**
  String get uBowl;

  /// No description provided for @uGlass.
  ///
  /// In fa, this message translates to:
  /// **'لیوان'**
  String get uGlass;

  /// No description provided for @uTablespoon.
  ///
  /// In fa, this message translates to:
  /// **'قاشق غذاخوری'**
  String get uTablespoon;

  /// No description provided for @uPalm.
  ///
  /// In fa, this message translates to:
  /// **'کف دست'**
  String get uPalm;

  /// No description provided for @uPiece.
  ///
  /// In fa, this message translates to:
  /// **'عدد'**
  String get uPiece;

  /// No description provided for @uGram.
  ///
  /// In fa, this message translates to:
  /// **'گرم'**
  String get uGram;

  /// No description provided for @uSlice.
  ///
  /// In fa, this message translates to:
  /// **'برش'**
  String get uSlice;

  /// No description provided for @month1.
  ///
  /// In fa, this message translates to:
  /// **'فروردین'**
  String get month1;

  /// No description provided for @month2.
  ///
  /// In fa, this message translates to:
  /// **'اردیبهشت'**
  String get month2;

  /// No description provided for @month3.
  ///
  /// In fa, this message translates to:
  /// **'خرداد'**
  String get month3;

  /// No description provided for @month4.
  ///
  /// In fa, this message translates to:
  /// **'تیر'**
  String get month4;

  /// No description provided for @month5.
  ///
  /// In fa, this message translates to:
  /// **'مرداد'**
  String get month5;

  /// No description provided for @month6.
  ///
  /// In fa, this message translates to:
  /// **'شهریور'**
  String get month6;

  /// No description provided for @month7.
  ///
  /// In fa, this message translates to:
  /// **'مهر'**
  String get month7;

  /// No description provided for @month8.
  ///
  /// In fa, this message translates to:
  /// **'آبان'**
  String get month8;

  /// No description provided for @month9.
  ///
  /// In fa, this message translates to:
  /// **'آذر'**
  String get month9;

  /// No description provided for @month10.
  ///
  /// In fa, this message translates to:
  /// **'دی'**
  String get month10;

  /// No description provided for @month11.
  ///
  /// In fa, this message translates to:
  /// **'بهمن'**
  String get month11;

  /// No description provided for @month12.
  ///
  /// In fa, this message translates to:
  /// **'اسفند'**
  String get month12;

  /// No description provided for @weekdaySat.
  ///
  /// In fa, this message translates to:
  /// **'شنبه'**
  String get weekdaySat;

  /// No description provided for @weekdayShortSat.
  ///
  /// In fa, this message translates to:
  /// **'ش'**
  String get weekdayShortSat;

  /// No description provided for @weekdaySun.
  ///
  /// In fa, this message translates to:
  /// **'یکشنبه'**
  String get weekdaySun;

  /// No description provided for @weekdayShortSun.
  ///
  /// In fa, this message translates to:
  /// **'ی'**
  String get weekdayShortSun;

  /// No description provided for @weekdayMon.
  ///
  /// In fa, this message translates to:
  /// **'دوشنبه'**
  String get weekdayMon;

  /// No description provided for @weekdayShortMon.
  ///
  /// In fa, this message translates to:
  /// **'د'**
  String get weekdayShortMon;

  /// No description provided for @weekdayTue.
  ///
  /// In fa, this message translates to:
  /// **'سه‌شنبه'**
  String get weekdayTue;

  /// No description provided for @weekdayShortTue.
  ///
  /// In fa, this message translates to:
  /// **'س'**
  String get weekdayShortTue;

  /// No description provided for @weekdayWed.
  ///
  /// In fa, this message translates to:
  /// **'چهارشنبه'**
  String get weekdayWed;

  /// No description provided for @weekdayShortWed.
  ///
  /// In fa, this message translates to:
  /// **'چ'**
  String get weekdayShortWed;

  /// No description provided for @weekdayThu.
  ///
  /// In fa, this message translates to:
  /// **'پنجشنبه'**
  String get weekdayThu;

  /// No description provided for @weekdayShortThu.
  ///
  /// In fa, this message translates to:
  /// **'پ'**
  String get weekdayShortThu;

  /// No description provided for @weekdayFri.
  ///
  /// In fa, this message translates to:
  /// **'جمعه'**
  String get weekdayFri;

  /// No description provided for @weekdayShortFri.
  ///
  /// In fa, this message translates to:
  /// **'ج'**
  String get weekdayShortFri;

  /// ترتیب اجزای تاریخ؛ در زبان‌های دیگر قابل تغییر
  ///
  /// In fa, this message translates to:
  /// **'{day} {month} {year}'**
  String dateLong(String day, String month, String year);

  /// No description provided for @dateWithWeekday.
  ///
  /// In fa, this message translates to:
  /// **'{weekday} {date}'**
  String dateWithWeekday(String weekday, String date);

  /// No description provided for @logSheetTitle.
  ///
  /// In fa, this message translates to:
  /// **'ثبت در {meal}'**
  String logSheetTitle(String meal);

  /// No description provided for @actionCamera.
  ///
  /// In fa, this message translates to:
  /// **'عکس'**
  String get actionCamera;

  /// No description provided for @actionGallery.
  ///
  /// In fa, this message translates to:
  /// **'گالری'**
  String get actionGallery;

  /// No description provided for @actionSearch.
  ///
  /// In fa, this message translates to:
  /// **'جستجو'**
  String get actionSearch;

  /// No description provided for @actionVoice.
  ///
  /// In fa, this message translates to:
  /// **'صوتی'**
  String get actionVoice;

  /// No description provided for @scanGuideTitle.
  ///
  /// In fa, this message translates to:
  /// **'راهنمای عکس گرفتن'**
  String get scanGuideTitle;

  /// No description provided for @scanGuide1.
  ///
  /// In fa, this message translates to:
  /// **'بشقاب را از بالا و کامل در کادر بگیر.'**
  String get scanGuide1;

  /// No description provided for @scanGuide2.
  ///
  /// In fa, this message translates to:
  /// **'نور کافی باشد و سایه روی غذا نیفتد.'**
  String get scanGuide2;

  /// No description provided for @scanGuide3.
  ///
  /// In fa, this message translates to:
  /// **'قاشق یا دست کنار بشقاب، به تخمین اندازه کمک می‌کند.'**
  String get scanGuide3;

  /// No description provided for @scanGuideOk.
  ///
  /// In fa, this message translates to:
  /// **'متوجه شدم، عکس بگیر'**
  String get scanGuideOk;

  /// No description provided for @analyzing.
  ///
  /// In fa, this message translates to:
  /// **'در حال تحلیل…'**
  String get analyzing;

  /// No description provided for @scanTip1.
  ///
  /// In fa, this message translates to:
  /// **'آب را قبل از غذا بنوش؛ به حس سیری کمک می‌کند.'**
  String get scanTip1;

  /// No description provided for @scanTip2.
  ///
  /// In fa, this message translates to:
  /// **'پروتئین کافی در هر وعده، گرسنگی را دیرتر می‌کند.'**
  String get scanTip2;

  /// No description provided for @scanTip3.
  ///
  /// In fa, this message translates to:
  /// **'آهسته غذا خوردن به بدن فرصت می‌دهد سیری را حس کند.'**
  String get scanTip3;

  /// No description provided for @scanTip4.
  ///
  /// In fa, this message translates to:
  /// **'سبزی خوردن و سالاد کنار غذا، بشقاب را پرتر و سبک‌تر می‌کند.'**
  String get scanTip4;

  /// No description provided for @scanTip5.
  ///
  /// In fa, this message translates to:
  /// **'ته‌دیگ خوشمزه است؛ فقط حواست به اندازه‌اش باشد!'**
  String get scanTip5;

  /// No description provided for @scanResultTitle.
  ///
  /// In fa, this message translates to:
  /// **'نتیجه‌ی تشخیص'**
  String get scanResultTitle;

  /// No description provided for @scanLowConfidence.
  ///
  /// In fa, this message translates to:
  /// **'مطمئن نیستیم، لطفاً بررسی کن.'**
  String get scanLowConfidence;

  /// No description provided for @scanNotFound.
  ///
  /// In fa, this message translates to:
  /// **'این غذا را پیدا نکردیم، انتخاب کن.'**
  String get scanNotFound;

  /// No description provided for @scanChooseFood.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب غذا'**
  String get scanChooseFood;

  /// No description provided for @scanChangeFood.
  ///
  /// In fa, this message translates to:
  /// **'تغییر غذا'**
  String get scanChangeFood;

  /// No description provided for @scanAddMissing.
  ///
  /// In fa, this message translates to:
  /// **'افزودن آیتم جاافتاده'**
  String get scanAddMissing;

  /// No description provided for @scanDetected.
  ///
  /// In fa, this message translates to:
  /// **'تشخیص: {name}'**
  String scanDetected(String name);

  /// No description provided for @scanNoItems.
  ///
  /// In fa, this message translates to:
  /// **'هیچ آیتمی نمانده. یک غذا اضافه کن یا عکس دیگری بگیر.'**
  String get scanNoItems;

  /// No description provided for @scanUnitAdjusted.
  ///
  /// In fa, this message translates to:
  /// **'واحد به {unit} تغییر کرد.'**
  String scanUnitAdjusted(String unit);

  /// No description provided for @scanNotFood.
  ///
  /// In fa, this message translates to:
  /// **'غذایی در عکس پیدا نشد.'**
  String get scanNotFood;

  /// No description provided for @scanNotFoodHint.
  ///
  /// In fa, this message translates to:
  /// **'سهمیه‌ات کم نشد. دوباره امتحان کن یا دستی ثبت کن.'**
  String get scanNotFoodHint;

  /// No description provided for @scanOfflineTitle.
  ///
  /// In fa, this message translates to:
  /// **'اینترنت نیست'**
  String get scanOfflineTitle;

  /// No description provided for @scanOfflineQueued.
  ///
  /// In fa, this message translates to:
  /// **'عکس ذخیره شد؛ وقتی وصل شدی تحلیلش می‌کنیم.'**
  String get scanOfflineQueued;

  /// No description provided for @scanTimeout.
  ///
  /// In fa, this message translates to:
  /// **'پاسخ دیر رسید. دوباره امتحان کن.'**
  String get scanTimeout;

  /// No description provided for @scanBusy.
  ///
  /// In fa, this message translates to:
  /// **'سرور شلوغ است. کمی بعد دوباره امتحان کن.'**
  String get scanBusy;

  /// No description provided for @scanRateLimited.
  ///
  /// In fa, this message translates to:
  /// **'چند اسکن پشت سر هم زدی؛ یک دقیقه صبر کن.'**
  String get scanRateLimited;

  /// No description provided for @scanBadImage.
  ///
  /// In fa, this message translates to:
  /// **'این عکس قابل استفاده نیست. عکس دیگری انتخاب کن.'**
  String get scanBadImage;

  /// No description provided for @scanError.
  ///
  /// In fa, this message translates to:
  /// **'تشخیص انجام نشد. دوباره امتحان کن.'**
  String get scanError;

  /// No description provided for @scanQuotaTitle.
  ///
  /// In fa, this message translates to:
  /// **'سهمیه‌ی اسکن امروز تمام شد'**
  String get scanQuotaTitle;

  /// No description provided for @scanQuotaHint.
  ///
  /// In fa, this message translates to:
  /// **'فردا سهمیه‌ی رایگانت دوباره پر می‌شود. تا آن موقع می‌توانی دستی ثبت کنی.'**
  String get scanQuotaHint;

  /// No description provided for @scanQuotaVideo.
  ///
  /// In fa, this message translates to:
  /// **'🎬 دیدن یک ویدیو = ۱ اسکن'**
  String get scanQuotaVideo;

  /// No description provided for @scanQuotaPremium.
  ///
  /// In fa, this message translates to:
  /// **'💎 اسکن نامحدود'**
  String get scanQuotaPremium;

  /// No description provided for @retry.
  ///
  /// In fa, this message translates to:
  /// **'دوباره'**
  String get retry;

  /// No description provided for @manualLog.
  ///
  /// In fa, this message translates to:
  /// **'ثبت دستی'**
  String get manualLog;

  /// No description provided for @takeAnother.
  ///
  /// In fa, this message translates to:
  /// **'عکس دیگر'**
  String get takeAnother;

  /// No description provided for @pendingReady.
  ///
  /// In fa, this message translates to:
  /// **'{count} عکس آماده‌ی بررسی است'**
  String pendingReady(String count);

  /// No description provided for @pendingQueued.
  ///
  /// In fa, this message translates to:
  /// **'{count} عکس در صف تحلیل (بعد از وصل شدن)'**
  String pendingQueued(String count);

  /// No description provided for @review.
  ///
  /// In fa, this message translates to:
  /// **'بررسی'**
  String get review;

  /// No description provided for @discard.
  ///
  /// In fa, this message translates to:
  /// **'کنار بگذار'**
  String get discard;

  /// No description provided for @confidenceValue.
  ///
  /// In fa, this message translates to:
  /// **'اطمینان {percent}٪'**
  String confidenceValue(String percent);

  /// No description provided for @streakTitle.
  ///
  /// In fa, this message translates to:
  /// **'زنجیره‌ی روزهای پیاپی'**
  String get streakTitle;

  /// No description provided for @streakDays.
  ///
  /// In fa, this message translates to:
  /// **'{n} روز پیاپی'**
  String streakDays(String n);

  /// No description provided for @streakRecord.
  ///
  /// In fa, this message translates to:
  /// **'رکورد: {n} روز'**
  String streakRecord(String n);

  /// No description provided for @streakZero.
  ///
  /// In fa, this message translates to:
  /// **'امروز یک غذا ثبت کن تا زنجیره شروع شود.'**
  String get streakZero;

  /// No description provided for @weightTitle.
  ///
  /// In fa, this message translates to:
  /// **'وزن'**
  String get weightTitle;

  /// No description provided for @logWeight.
  ///
  /// In fa, this message translates to:
  /// **'ثبت وزن'**
  String get logWeight;

  /// No description provided for @weightStart.
  ///
  /// In fa, this message translates to:
  /// **'شروع'**
  String get weightStart;

  /// No description provided for @weightCurrent.
  ///
  /// In fa, this message translates to:
  /// **'فعلی'**
  String get weightCurrent;

  /// No description provided for @weightGoalLabel.
  ///
  /// In fa, this message translates to:
  /// **'هدف'**
  String get weightGoalLabel;

  /// No description provided for @weightChangeFromStart.
  ///
  /// In fa, this message translates to:
  /// **'تغییر از شروع: {amount} {unit}'**
  String weightChangeFromStart(String amount, String unit);

  /// No description provided for @noWeights.
  ///
  /// In fa, this message translates to:
  /// **'هنوز وزنی ثبت نشده.'**
  String get noWeights;

  /// No description provided for @deleteWeightConfirm.
  ///
  /// In fa, this message translates to:
  /// **'این ثبت وزن حذف شود؟'**
  String get deleteWeightConfirm;

  /// No description provided for @caloriesTitle.
  ///
  /// In fa, this message translates to:
  /// **'کالری روزانه'**
  String get caloriesTitle;

  /// No description provided for @range7.
  ///
  /// In fa, this message translates to:
  /// **'۷ روز'**
  String get range7;

  /// No description provided for @range30.
  ///
  /// In fa, this message translates to:
  /// **'۳۰ روز'**
  String get range30;

  /// No description provided for @avgKcal.
  ///
  /// In fa, this message translates to:
  /// **'میانگین روزهای ثبت‌شده: {kcal} کالری'**
  String avgKcal(String kcal);

  /// No description provided for @avgMacros.
  ///
  /// In fa, this message translates to:
  /// **'میانگین پروتئین {p}، کربوهیدرات {c}، چربی {f} گرم'**
  String avgMacros(String p, String c, String f);

  /// No description provided for @noLogsRange.
  ///
  /// In fa, this message translates to:
  /// **'در این بازه چیزی ثبت نشده.'**
  String get noLogsRange;

  /// No description provided for @badgesTitle.
  ///
  /// In fa, this message translates to:
  /// **'نشان‌ها'**
  String get badgesTitle;

  /// No description provided for @badgeFirstLog.
  ///
  /// In fa, this message translates to:
  /// **'اولین ثبت'**
  String get badgeFirstLog;

  /// No description provided for @badgeFirstLogDesc.
  ///
  /// In fa, this message translates to:
  /// **'اولین غذایت را ثبت کردی'**
  String get badgeFirstLogDesc;

  /// No description provided for @badgeStreak3.
  ///
  /// In fa, this message translates to:
  /// **'۳ روز پیاپی'**
  String get badgeStreak3;

  /// No description provided for @badgeStreak3Desc.
  ///
  /// In fa, this message translates to:
  /// **'سه روز پشت سر هم ثبت کردی'**
  String get badgeStreak3Desc;

  /// No description provided for @badgeStreak7.
  ///
  /// In fa, this message translates to:
  /// **'۷ روز پیاپی'**
  String get badgeStreak7;

  /// No description provided for @badgeStreak7Desc.
  ///
  /// In fa, this message translates to:
  /// **'یک هفته‌ی کامل، بدون وقفه'**
  String get badgeStreak7Desc;

  /// No description provided for @badgeFirstKg.
  ///
  /// In fa, this message translates to:
  /// **'اولین کیلو'**
  String get badgeFirstKg;

  /// No description provided for @badgeFirstKgDesc.
  ///
  /// In fa, this message translates to:
  /// **'اولین کیلو در مسیر هدفت'**
  String get badgeFirstKgDesc;

  /// No description provided for @badgeWater8.
  ///
  /// In fa, this message translates to:
  /// **'۸ لیوان آب'**
  String get badgeWater8;

  /// No description provided for @badgeWater8Desc.
  ///
  /// In fa, this message translates to:
  /// **'یک روز کامل آب کافی نوشیدی'**
  String get badgeWater8Desc;

  /// No description provided for @badgeLocked.
  ///
  /// In fa, this message translates to:
  /// **'هنوز نه'**
  String get badgeLocked;

  /// No description provided for @beforeAfterTitle.
  ///
  /// In fa, this message translates to:
  /// **'عکس قبل و بعد'**
  String get beforeAfterTitle;

  /// No description provided for @beforeAfterPrivacy.
  ///
  /// In fa, this message translates to:
  /// **'این عکس‌ها فقط روی گوشی خودت می‌مانند و هرگز آپلود نمی‌شوند.'**
  String get beforeAfterPrivacy;

  /// No description provided for @photoBefore.
  ///
  /// In fa, this message translates to:
  /// **'قبل'**
  String get photoBefore;

  /// No description provided for @photoAfter.
  ///
  /// In fa, this message translates to:
  /// **'بعد'**
  String get photoAfter;

  /// No description provided for @addPhoto.
  ///
  /// In fa, this message translates to:
  /// **'افزودن عکس'**
  String get addPhoto;

  /// No description provided for @removePhoto.
  ///
  /// In fa, this message translates to:
  /// **'حذف عکس'**
  String get removePhoto;

  /// No description provided for @shareCard.
  ///
  /// In fa, this message translates to:
  /// **'ساخت کارت اشتراک'**
  String get shareCard;

  /// No description provided for @shareStreak.
  ///
  /// In fa, this message translates to:
  /// **'اشتراک زنجیره'**
  String get shareStreak;

  /// No description provided for @shareNow.
  ///
  /// In fa, this message translates to:
  /// **'اشتراک‌گذاری'**
  String get shareNow;

  /// No description provided for @cardStreak.
  ///
  /// In fa, this message translates to:
  /// **'روز پیاپی'**
  String get cardStreak;

  /// No description provided for @cardWeightChange.
  ///
  /// In fa, this message translates to:
  /// **'{amount} {unit} در {days} روز'**
  String cardWeightChange(String amount, String unit, String days);

  /// No description provided for @cardTagline.
  ///
  /// In fa, this message translates to:
  /// **'کالری شمار با عکس، برای غذای ایرانی'**
  String get cardTagline;

  /// No description provided for @shareText.
  ///
  /// In fa, this message translates to:
  /// **'مسیرم را با کالری‌لنز ثبت می‌کنم 💪'**
  String get shareText;

  /// No description provided for @remindersTitle.
  ///
  /// In fa, this message translates to:
  /// **'یادآورها'**
  String get remindersTitle;

  /// No description provided for @remindMeals.
  ///
  /// In fa, this message translates to:
  /// **'یادآور وعده‌ها'**
  String get remindMeals;

  /// No description provided for @remindWater.
  ///
  /// In fa, this message translates to:
  /// **'یادآور آب'**
  String get remindWater;

  /// No description provided for @remindWaterEvery.
  ///
  /// In fa, this message translates to:
  /// **'هر {n} ساعت، از {from} تا {to}'**
  String remindWaterEvery(String n, String from, String to);

  /// No description provided for @remindWeight.
  ///
  /// In fa, this message translates to:
  /// **'یادآور ثبت وزن (هفتگی)'**
  String get remindWeight;

  /// No description provided for @remindPermissionDenied.
  ///
  /// In fa, this message translates to:
  /// **'اجازه‌ی اعلان داده نشد. از تنظیمات گوشی فعالش کن.'**
  String get remindPermissionDenied;

  /// No description provided for @remindSaved.
  ///
  /// In fa, this message translates to:
  /// **'یادآورها تنظیم شد'**
  String get remindSaved;

  /// No description provided for @notifBreakfastTitle.
  ///
  /// In fa, this message translates to:
  /// **'وقت صبحانه 🍳'**
  String get notifBreakfastTitle;

  /// No description provided for @notifBreakfastBody.
  ///
  /// In fa, this message translates to:
  /// **'صبحانه‌ات را با یک عکس ثبت کن.'**
  String get notifBreakfastBody;

  /// No description provided for @notifLunchTitle.
  ///
  /// In fa, this message translates to:
  /// **'وقت ناهار 🍛'**
  String get notifLunchTitle;

  /// No description provided for @notifLunchBody.
  ///
  /// In fa, this message translates to:
  /// **'ناهار امروز چی بود؟ یک عکس کافی است.'**
  String get notifLunchBody;

  /// No description provided for @notifDinnerTitle.
  ///
  /// In fa, this message translates to:
  /// **'وقت شام 🌙'**
  String get notifDinnerTitle;

  /// No description provided for @notifDinnerBody.
  ///
  /// In fa, this message translates to:
  /// **'شامت را ثبت کن تا روزت کامل شود.'**
  String get notifDinnerBody;

  /// No description provided for @notifWaterTitle.
  ///
  /// In fa, this message translates to:
  /// **'یک لیوان آب 💧'**
  String get notifWaterTitle;

  /// No description provided for @notifWaterBody.
  ///
  /// In fa, this message translates to:
  /// **'بدنت از آب کافی تشکر می‌کند.'**
  String get notifWaterBody;

  /// No description provided for @notifWeightTitle.
  ///
  /// In fa, this message translates to:
  /// **'ثبت وزن هفتگی ⚖️'**
  String get notifWeightTitle;

  /// No description provided for @notifWeightBody.
  ///
  /// In fa, this message translates to:
  /// **'وزن این هفته را ثبت کن؛ هر عددی باشد، قدمی در مسیر است.'**
  String get notifWeightBody;

  /// No description provided for @widgetRemaining.
  ///
  /// In fa, this message translates to:
  /// **'کالری باقی‌مانده'**
  String get widgetRemaining;

  /// No description provided for @widgetOver.
  ///
  /// In fa, this message translates to:
  /// **'بیشتر از هدف امروز'**
  String get widgetOver;

  /// No description provided for @widgetDetail.
  ///
  /// In fa, this message translates to:
  /// **'{consumed} از {goal} کالری'**
  String widgetDetail(String consumed, String goal);

  /// No description provided for @rateTitle.
  ///
  /// In fa, this message translates to:
  /// **'از کالری‌لنز راضی هستی؟'**
  String get rateTitle;

  /// No description provided for @rateBody.
  ///
  /// In fa, this message translates to:
  /// **'اگر کمکت کرده، با امتیاز دادن در {store} به ما کمک کن تا بهتر شویم.'**
  String rateBody(String store);

  /// No description provided for @rateYes.
  ///
  /// In fa, this message translates to:
  /// **'امتیاز می‌دهم'**
  String get rateYes;

  /// No description provided for @rateLater.
  ///
  /// In fa, this message translates to:
  /// **'بعداً'**
  String get rateLater;

  /// No description provided for @rateNever.
  ///
  /// In fa, this message translates to:
  /// **'نه، ممنون'**
  String get rateNever;

  /// No description provided for @storeBazaar.
  ///
  /// In fa, this message translates to:
  /// **'کافه‌بازار'**
  String get storeBazaar;

  /// No description provided for @storeMyket.
  ///
  /// In fa, this message translates to:
  /// **'مایکت'**
  String get storeMyket;

  /// No description provided for @storeGeneric.
  ///
  /// In fa, this message translates to:
  /// **'فروشگاه'**
  String get storeGeneric;

  /// No description provided for @adLabel.
  ///
  /// In fa, this message translates to:
  /// **'تبلیغ'**
  String get adLabel;

  /// No description provided for @premiumTitle.
  ///
  /// In fa, this message translates to:
  /// **'کالری‌لنز ویژه 💎'**
  String get premiumTitle;

  /// No description provided for @premiumBenefitScan.
  ///
  /// In fa, this message translates to:
  /// **'اسکن نامحدود عکس (سقف منصفانه‌ی ۳۰ در روز)'**
  String get premiumBenefitScan;

  /// No description provided for @premiumBenefitNoAds.
  ///
  /// In fa, this message translates to:
  /// **'بدون هیچ تبلیغی'**
  String get premiumBenefitNoAds;

  /// No description provided for @premiumBenefitMore.
  ///
  /// In fa, this message translates to:
  /// **'امکانات ویژه‌ی بعدی هم برای تو باز می‌شوند'**
  String get premiumBenefitMore;

  /// No description provided for @planMonthly.
  ///
  /// In fa, this message translates to:
  /// **'ماهانه'**
  String get planMonthly;

  /// No description provided for @planQuarterly.
  ///
  /// In fa, this message translates to:
  /// **'سه‌ماهه'**
  String get planQuarterly;

  /// No description provided for @planYearly.
  ///
  /// In fa, this message translates to:
  /// **'سالانه'**
  String get planYearly;

  /// No description provided for @bestValue.
  ///
  /// In fa, this message translates to:
  /// **'به‌صرفه‌ترین'**
  String get bestValue;

  /// No description provided for @priceInStore.
  ///
  /// In fa, this message translates to:
  /// **'قیمت در فروشگاه'**
  String get priceInStore;

  /// No description provided for @buy.
  ///
  /// In fa, this message translates to:
  /// **'خرید'**
  String get buy;

  /// No description provided for @notNow.
  ///
  /// In fa, this message translates to:
  /// **'فعلاً نه'**
  String get notNow;

  /// No description provided for @restorePurchases.
  ///
  /// In fa, this message translates to:
  /// **'بازیابی خرید'**
  String get restorePurchases;

  /// No description provided for @purchaseSuccess.
  ///
  /// In fa, this message translates to:
  /// **'اشتراک ویژه فعال شد 💎'**
  String get purchaseSuccess;

  /// No description provided for @purchaseUnavailable.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت هنوز فعال نشده است.'**
  String get purchaseUnavailable;

  /// No description provided for @purchaseFailed.
  ///
  /// In fa, this message translates to:
  /// **'خرید تأیید نشد. اگر مبلغی کم شده، «بازیابی خرید» را بزن.'**
  String get purchaseFailed;

  /// No description provided for @restoreNone.
  ///
  /// In fa, this message translates to:
  /// **'خریدی برای بازیابی پیدا نشد.'**
  String get restoreNone;

  /// No description provided for @premiumActiveUntil.
  ///
  /// In fa, this message translates to:
  /// **'ویژه تا {date}'**
  String premiumActiveUntil(String date);

  /// No description provided for @upgradePremium.
  ///
  /// In fa, this message translates to:
  /// **'ارتقا به ویژه 💎'**
  String get upgradePremium;

  /// No description provided for @rewardGranted.
  ///
  /// In fa, this message translates to:
  /// **'۱ اسکن به سهمیه‌ات اضافه شد'**
  String get rewardGranted;

  /// No description provided for @rewardNotCompleted.
  ///
  /// In fa, this message translates to:
  /// **'ویدیو کامل دیده نشد؛ اسکنی اضافه نشد.'**
  String get rewardNotCompleted;

  /// No description provided for @rewardUnavailable.
  ///
  /// In fa, this message translates to:
  /// **'الان ویدیویی برای نمایش نیست.'**
  String get rewardUnavailable;

  /// No description provided for @rewardLimit.
  ///
  /// In fa, this message translates to:
  /// **'سقف ویدیوی امروز پر شده است.'**
  String get rewardLimit;

  /// No description provided for @rewardFailed.
  ///
  /// In fa, this message translates to:
  /// **'ثبت پاداش انجام نشد. دوباره امتحان کن.'**
  String get rewardFailed;

  /// No description provided for @mealSuhoor.
  ///
  /// In fa, this message translates to:
  /// **'سحر'**
  String get mealSuhoor;

  /// No description provided for @mealIftar.
  ///
  /// In fa, this message translates to:
  /// **'افطار'**
  String get mealIftar;

  /// No description provided for @ramadanMode.
  ///
  /// In fa, this message translates to:
  /// **'حالت رمضان'**
  String get ramadanMode;

  /// No description provided for @ramadanModeDesc.
  ///
  /// In fa, this message translates to:
  /// **'سحر و افطار به‌جای صبحانه و شام؛ یادآور آب بین افطار و سحر'**
  String get ramadanModeDesc;

  /// No description provided for @notifSuhoorTitle.
  ///
  /// In fa, this message translates to:
  /// **'وقت سحر 🌙'**
  String get notifSuhoorTitle;

  /// No description provided for @notifSuhoorBody.
  ///
  /// In fa, this message translates to:
  /// **'سحری‌ات را ثبت کن؛ آب کافی هم یادت نرود.'**
  String get notifSuhoorBody;

  /// No description provided for @notifIftarTitle.
  ///
  /// In fa, this message translates to:
  /// **'افطار 🌅'**
  String get notifIftarTitle;

  /// No description provided for @notifIftarBody.
  ///
  /// In fa, this message translates to:
  /// **'قبول باشد! افطارت را با یک عکس ثبت کن.'**
  String get notifIftarBody;

  /// No description provided for @voiceTitle.
  ///
  /// In fa, this message translates to:
  /// **'ثبت صوتی یا متنی'**
  String get voiceTitle;

  /// No description provided for @voiceHold.
  ///
  /// In fa, this message translates to:
  /// **'نگه دار و بگو'**
  String get voiceHold;

  /// No description provided for @voiceListening.
  ///
  /// In fa, this message translates to:
  /// **'در حال شنیدن…'**
  String get voiceListening;

  /// No description provided for @voiceHint.
  ///
  /// In fa, this message translates to:
  /// **'مثلاً: «ناهار یه بشقاب قیمه با برنج و یه دوغ خوردم»'**
  String get voiceHint;

  /// No description provided for @voiceTypeHint.
  ///
  /// In fa, this message translates to:
  /// **'یا اینجا بنویس…'**
  String get voiceTypeHint;

  /// No description provided for @voiceSend.
  ///
  /// In fa, this message translates to:
  /// **'ثبت'**
  String get voiceSend;

  /// No description provided for @voiceUnavailable.
  ///
  /// In fa, this message translates to:
  /// **'تشخیص گفتار روی این گوشی در دسترس نیست؛ جمله را تایپ کن.'**
  String get voiceUnavailable;

  /// No description provided for @voiceNotFood.
  ///
  /// In fa, this message translates to:
  /// **'در این جمله غذایی پیدا نشد. دوباره بگو یا بنویس.'**
  String get voiceNotFood;

  /// No description provided for @voiceQuota.
  ///
  /// In fa, this message translates to:
  /// **'سهمیه‌ی ثبت صوتی امروز تمام شد. ثبت دستی همیشه رایگان است.'**
  String get voiceQuota;

  /// No description provided for @customMeals.
  ///
  /// In fa, this message translates to:
  /// **'غذاهای ترکیبی من'**
  String get customMeals;

  /// No description provided for @saveAsCustomMeal.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره به‌عنوان غذای ترکیبی'**
  String get saveAsCustomMeal;

  /// No description provided for @customMealName.
  ///
  /// In fa, this message translates to:
  /// **'نام غذای ترکیبی'**
  String get customMealName;

  /// No description provided for @customMealNameHint.
  ///
  /// In fa, this message translates to:
  /// **'مثلاً «صبحانه‌ی همیشگی»'**
  String get customMealNameHint;

  /// No description provided for @customMealSaved.
  ///
  /// In fa, this message translates to:
  /// **'«{name}» ذخیره شد'**
  String customMealSaved(String name);

  /// No description provided for @customMealItems.
  ///
  /// In fa, this message translates to:
  /// **'{n} قلم'**
  String customMealItems(String n);

  /// No description provided for @customMealLogged.
  ///
  /// In fa, this message translates to:
  /// **'{n} قلم ثبت شد'**
  String customMealLogged(String n);

  /// No description provided for @customMealDeleteConfirm.
  ///
  /// In fa, this message translates to:
  /// **'«{name}» حذف شود؟'**
  String customMealDeleteConfirm(String name);

  /// No description provided for @copyYesterday.
  ///
  /// In fa, this message translates to:
  /// **'کپی از دیروز'**
  String get copyYesterday;

  /// No description provided for @copiedYesterday.
  ///
  /// In fa, this message translates to:
  /// **'{n} قلم از دیروز کپی شد'**
  String copiedYesterday(String n);

  /// No description provided for @nothingYesterday.
  ///
  /// In fa, this message translates to:
  /// **'دیروز در این وعده چیزی ثبت نشده.'**
  String get nothingYesterday;

  /// No description provided for @inviteTitle.
  ///
  /// In fa, this message translates to:
  /// **'دعوت از دوستان'**
  String get inviteTitle;

  /// No description provided for @inviteDesc.
  ///
  /// In fa, this message translates to:
  /// **'هر دوستی که با کد تو بیاید، هر دوی شما {days} روز ویژه می‌گیرید.'**
  String inviteDesc(String days);

  /// No description provided for @inviteYourCode.
  ///
  /// In fa, this message translates to:
  /// **'کد دعوت تو'**
  String get inviteYourCode;

  /// No description provided for @inviteCopied.
  ///
  /// In fa, this message translates to:
  /// **'کد کپی شد'**
  String get inviteCopied;

  /// No description provided for @inviteShare.
  ///
  /// In fa, this message translates to:
  /// **'ارسال برای دوستان'**
  String get inviteShare;

  /// No description provided for @inviteShareText.
  ///
  /// In fa, this message translates to:
  /// **'کالری‌لنز رو نصب کن و کد {code} رو وارد کن؛ هر دومون {days} روز ویژه می‌گیریم 🎁'**
  String inviteShareText(String code, String days);

  /// No description provided for @inviteCount.
  ///
  /// In fa, this message translates to:
  /// **'{n} دوست با کد تو آمده‌اند'**
  String inviteCount(String n);

  /// No description provided for @inviteEnter.
  ///
  /// In fa, this message translates to:
  /// **'کد دعوت داری؟'**
  String get inviteEnter;

  /// No description provided for @inviteRedeem.
  ///
  /// In fa, this message translates to:
  /// **'ثبت کد'**
  String get inviteRedeem;

  /// No description provided for @inviteRedeemed.
  ///
  /// In fa, this message translates to:
  /// **'هدیه فعال شد 🎁'**
  String get inviteRedeemed;

  /// No description provided for @inviteInvalid.
  ///
  /// In fa, this message translates to:
  /// **'این کد پیدا نشد.'**
  String get inviteInvalid;

  /// No description provided for @inviteOwn.
  ///
  /// In fa, this message translates to:
  /// **'کد خودت را نمی‌توانی وارد کنی.'**
  String get inviteOwn;

  /// No description provided for @inviteAlready.
  ///
  /// In fa, this message translates to:
  /// **'قبلاً یک کد دعوت وارد کرده‌ای.'**
  String get inviteAlready;

  /// No description provided for @inviteOffline.
  ///
  /// In fa, this message translates to:
  /// **'برای دعوت به اینترنت نیاز است.'**
  String get inviteOffline;

  /// No description provided for @wrongDetection.
  ///
  /// In fa, this message translates to:
  /// **'تشخیص اشتباه بود؟'**
  String get wrongDetection;

  /// No description provided for @wrongDetectionTitle.
  ///
  /// In fa, this message translates to:
  /// **'گزارش تشخیص اشتباه'**
  String get wrongDetectionTitle;

  /// No description provided for @wrongDetectionHint.
  ///
  /// In fa, this message translates to:
  /// **'اصلاحاتی که در فهرست کردی همراه گزارش فرستاده می‌شود (بدون عکس). اگر توضیحی داری بنویس:'**
  String get wrongDetectionHint;

  /// No description provided for @wrongDetectionSend.
  ///
  /// In fa, this message translates to:
  /// **'ارسال گزارش'**
  String get wrongDetectionSend;

  /// No description provided for @wrongDetectionThanks.
  ///
  /// In fa, this message translates to:
  /// **'ممنون! برای بهتر شدن تشخیص استفاده می‌شود.'**
  String get wrongDetectionThanks;

  /// No description provided for @aboutTitle.
  ///
  /// In fa, this message translates to:
  /// **'درباره‌ی کالری‌لنز'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In fa, this message translates to:
  /// **'نسخه‌ی {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutTagline.
  ///
  /// In fa, this message translates to:
  /// **'کالری‌شمار عکسی غذاهای ایرانی'**
  String get aboutTagline;

  /// No description provided for @privacyTitle.
  ///
  /// In fa, this message translates to:
  /// **'حریم خصوصی'**
  String get privacyTitle;

  /// No description provided for @disclaimerTitle.
  ///
  /// In fa, this message translates to:
  /// **'سلب مسئولیت پزشکی'**
  String get disclaimerTitle;

  /// متن کامل سلب مسئولیت (بخش ۶-۵)
  ///
  /// In fa, this message translates to:
  /// **'کالری‌لنز ابزاری برای آگاهی از تغذیه است و جایگزین پزشک، متخصص تغذیه یا مشاوره‌ی درمانی نیست.\n\n• همه‌ی اعداد (کالری، درشت‌مغذی‌ها، وزن هدف و زمان رسیدن به آن) تخمینی‌اند. تشخیص غذا از عکس یا جمله ممکن است اشتباه باشد؛ همیشه نتیجه را بررسی کن.\n• محاسبه‌ی کالری روزانه با فرمول عمومی Mifflin-St Jeor انجام می‌شود و شرایط خاص بدن تو را در نظر نمی‌گیرد.\n• کالری روزانه هرگز کمتر از ۱۲۰۰ (زن) و ۱۵۰۰ (مرد) پیشنهاد نمی‌شود.\n• برای زیر ۱۸ سال، دوران بارداری و شیردهی، و کسانی که بیماری (مثل دیابت، بیماری قلبی یا کلیوی) یا سابقه‌ی اختلال خوردن دارند، پیش از هر تغییر در رژیم غذایی حتماً با پزشک مشورت کن.\n• اگر هنگام رژیم احساس ضعف، سرگیجه یا مشکل دیگری داشتی، رژیم را متوقف کن و به پزشک مراجعه کن.'**
  String get disclaimerBody;

  /// متن حریم خصوصی؛ پیش از انتشار جاهای [ ] را پر کنید
  ///
  /// In fa, this message translates to:
  /// **'ما به حریم خصوصی تو احترام می‌گذاریم. خلاصه: بیشتر داده‌هایت فقط روی گوشی خودت است.\n\n۱. داده‌هایی که فقط روی گوشی می‌مانند\nپروفایل (سن، قد، وزن، هدف)، غذاهای ثبت‌شده، وزن‌ها، آب، یادآورها، عکس‌های غذا (برای نمایش کوچک کنار ثبت‌ها) و عکس‌های «قبل و بعد». عکس‌های قبل و بعد هرگز آپلود نمی‌شوند.\n\n۲. داده‌هایی که به سرور ما فرستاده می‌شود\n• شناسه‌ی تصادفی دستگاه: هنگام اولین استفاده ساخته می‌شود و به نام، شماره یا ایمیل تو ربطی ندارد.\n• عکس غذا هنگام اسکن: برای تشخیص فرستاده می‌شود و ذخیره نمی‌شود. فقط نتیجه‌ی تشخیص (بدون عکس) تا ۷ روز برای سرعت بیشتر نگه داشته می‌شود.\n• متن جمله در ثبت صوتی یا متنی: صدا روی گوشی به متن تبدیل می‌شود و فقط متن به سرور می‌آید. سرویس گفتار گوشی (معمولاً Google) ممکن است صدا را طبق سیاست خودش پردازش کند.\n• گزارش «تشخیص اشتباه بود»: فهرست اصلاح‌شده‌ی غذاها و توضیح تو، بدون عکس.\n• تعداد استفاده‌ی روزانه (برای سهمیه)، کد دعوت و اطلاعات خرید اشتراک (برای اعتبارسنجی در فروشگاه).\n• آمار ناشناس استفاده (مثل «یک اسکن انجام شد»)، بدون هیچ داده‌ی شخصی یا غذایی. می‌توانی آن را در همین صفحه خاموش کنی.\n\n۳. سرویس‌های دیگر\n• تشخیص غذا و فهم جمله را یک سرویس هوش مصنوعی ([نام ارائه‌دهنده]) انجام می‌دهد؛ عکس یا متن فقط برای همین کار به آن فرستاده می‌شود.\n• پرداخت از طریق کافه‌بازار یا مایکت انجام می‌شود؛ ما اطلاعات کارت بانکی تو را نمی‌بینیم.\n• در نسخه‌ی رایگان، تبلیغات از طریق تپسل نمایش داده می‌شود که ممکن است شناسه‌ی تبلیغاتی گوشی را طبق سیاست خودش استفاده کند.\n\n۴. حذف داده‌ها\nبا «حذف همه‌ی داده‌ها» در تنظیمات، همه‌ی داده‌های روی گوشی و داده‌های این دستگاه روی سرور پاک می‌شود. فقط سابقه‌ی خرید اشتراک (بدون ارتباط با دستگاه) برای امکان «بازیابی خرید» باقی می‌ماند.\n\n۵. کودکان\nبرای کاربران زیر ۱۸ سال، هدف کاهش وزن غیرفعال است و فقط «تغذیه‌ی سالم» پیشنهاد می‌شود.\n\n۶. تماس\nپرسش یا درخواست: [ایمیل یا آیدی پشتیبانی]'**
  String get privacyBody;

  /// No description provided for @licenses.
  ///
  /// In fa, this message translates to:
  /// **'مجوزهای نرم‌افزار'**
  String get licenses;

  /// No description provided for @analyticsToggle.
  ///
  /// In fa, this message translates to:
  /// **'ارسال آمار ناشناس استفاده'**
  String get analyticsToggle;

  /// No description provided for @analyticsToggleDesc.
  ///
  /// In fa, this message translates to:
  /// **'فقط شمارش رویدادها (مثل «یک اسکن»)، بدون داده‌ی شخصی؛ برای بهتر شدن اپ'**
  String get analyticsToggleDesc;

  /// No description provided for @deleteAllData.
  ///
  /// In fa, this message translates to:
  /// **'حذف همه‌ی داده‌ها'**
  String get deleteAllData;

  /// No description provided for @deleteAllDesc.
  ///
  /// In fa, this message translates to:
  /// **'همه‌ی ثبت‌ها، وزن‌ها، عکس‌ها و تنظیمات روی گوشی، و داده‌های این دستگاه روی سرور پاک می‌شود. این کار برگشت‌پذیر نیست.'**
  String get deleteAllDesc;

  /// No description provided for @deleteAllConfirm.
  ///
  /// In fa, this message translates to:
  /// **'برای تأیید، کلمه‌ی «حذف» را بنویس:'**
  String get deleteAllConfirm;

  /// No description provided for @deleteAllWord.
  ///
  /// In fa, this message translates to:
  /// **'حذف'**
  String get deleteAllWord;

  /// No description provided for @deleteAllDone.
  ///
  /// In fa, this message translates to:
  /// **'همه‌ی داده‌ها پاک شد.'**
  String get deleteAllDone;

  /// No description provided for @deleteAllServerFailed.
  ///
  /// In fa, this message translates to:
  /// **'داده‌های گوشی پاک شد، ولی اتصال به سرور برقرار نشد؛ داده‌های این دستگاه روی سرور (فقط آمار استفاده) باقی ماند.'**
  String get deleteAllServerFailed;

  /// No description provided for @openSettingsInfo.
  ///
  /// In fa, this message translates to:
  /// **'درباره، حریم خصوصی و داده‌ها'**
  String get openSettingsInfo;

  /// No description provided for @serverUrlTitle.
  ///
  /// In fa, this message translates to:
  /// **'آدرس سرور'**
  String get serverUrlTitle;

  /// No description provided for @serverUrlNotSet.
  ///
  /// In fa, this message translates to:
  /// **'وارد نشده؛ اسکن و ثبت صوتی کار نمی‌کند'**
  String get serverUrlNotSet;

  /// No description provided for @serverUrlHint.
  ///
  /// In fa, this message translates to:
  /// **'آدرسی که مدیر اپ به تو داده، مثل api.example.ir'**
  String get serverUrlHint;

  /// No description provided for @serverUrlInvalid.
  ///
  /// In fa, this message translates to:
  /// **'آدرس درست نیست. باید یک آدرس امن (https) باشد.'**
  String get serverUrlInvalid;

  /// No description provided for @serverUrlUnreachable.
  ///
  /// In fa, this message translates to:
  /// **'به این آدرس وصل نشدم یا سرور کالری‌لنز نیست. آدرس و اینترنت را بررسی کن.'**
  String get serverUrlUnreachable;

  /// No description provided for @serverUrlSaved.
  ///
  /// In fa, this message translates to:
  /// **'به سرور وصل شد و ذخیره شد.'**
  String get serverUrlSaved;

  /// No description provided for @serverUrlCheck.
  ///
  /// In fa, this message translates to:
  /// **'بررسی و ذخیره'**
  String get serverUrlCheck;

  /// No description provided for @serverUrlChecking.
  ///
  /// In fa, this message translates to:
  /// **'در حال بررسی…'**
  String get serverUrlChecking;
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
