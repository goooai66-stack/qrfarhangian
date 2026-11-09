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
  String get progressPlaceholder =>
      'ثبت وزن و نمودارها در مرحله‌ی ۴ ساخته می‌شود.';

  @override
  String get plansPlaceholder =>
      'برنامه‌ها و چالش‌ها در نسخه‌های بعدی می‌آیند.';

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

  @override
  String get next => 'بعدی';

  @override
  String get back => 'قبلی';

  @override
  String get save => 'ذخیره';

  @override
  String get saved => 'ذخیره شد';

  @override
  String get cancel => 'انصراف';

  @override
  String get confirm => 'تأیید';

  @override
  String get yes => 'بله';

  @override
  String get no => 'خیر';

  @override
  String stepOf(String current, String total) {
    return '$current از $total';
  }

  @override
  String get qSex => 'جنسیتت چیست؟';

  @override
  String get sexMale => 'مرد';

  @override
  String get sexFemale => 'زن';

  @override
  String get qBirthDate => 'تاریخ تولدت؟';

  @override
  String ageYears(String age) {
    return '$age سال';
  }

  @override
  String get dateDay => 'روز';

  @override
  String get dateMonth => 'ماه';

  @override
  String get dateYear => 'سال';

  @override
  String get qPregnancy => 'باردار هستی یا به نوزاد شیر می‌دهی؟';

  @override
  String get pregnancyHint =>
      'در این دوران، کم کردن کالری فقط با نظر پزشک توصیه می‌شود.';

  @override
  String get qHeight => 'قدت چقدر است؟';

  @override
  String get unitCm => 'سانتی‌متر';

  @override
  String cmValue(String value) {
    return '$value سانتی‌متر';
  }

  @override
  String get qWeight => 'وزن فعلی‌ات؟';

  @override
  String get unitKg => 'کیلوگرم';

  @override
  String kgValue(String value) {
    return '$value کیلوگرم';
  }

  @override
  String bmiValue(String bmi) {
    return 'شاخص توده‌ی بدنی (BMI): $bmi';
  }

  @override
  String get qGoal => 'هدفت چیست؟';

  @override
  String get goalLose => 'کاهش وزن';

  @override
  String get goalMaintain => 'حفظ وزن';

  @override
  String get goalGain => 'افزایش وزن';

  @override
  String get goalHealthyEating => 'تغذیه‌ی سالم';

  @override
  String get goalBlockedMinor =>
      'برای زیر ۱۸ سال فقط برنامه‌ی تغذیه‌ی سالم داریم. برای تغییر وزن با پزشک مشورت کن.';

  @override
  String get goalBlockedPregnancy =>
      'در دوران بارداری و شیردهی، کاهش کالری فقط با نظر پزشک.';

  @override
  String get goalBlockedLowBmi =>
      'وزنت در محدوده‌ی کم است؛ کاهش وزن برایت مناسب نیست.';

  @override
  String get qGoalWeight => 'وزن هدفت؟';

  @override
  String goalWeightRange(String min, String max) {
    return 'بین $min تا $max کیلوگرم';
  }

  @override
  String goalWeightDiff(String kg) {
    return 'تغییر: $kg کیلوگرم';
  }

  @override
  String get invalidGoalWeight => 'وزن هدف با هدف انتخاب‌شده جور نیست.';

  @override
  String get qRate => 'با چه سرعتی؟';

  @override
  String get rateSlow => 'آرام';

  @override
  String get rateNormal => 'متعادل';

  @override
  String get rateFast => 'سریع';

  @override
  String rateValue(String kg) {
    return '$kg کیلو در هفته';
  }

  @override
  String rateKcal(String kcal) {
    return 'حدود $kcal کالری در روز';
  }

  @override
  String get rateFloorHint =>
      'این سرعت برایت زیاد است؛ کالری روی حداقل ایمن می‌ماند.';

  @override
  String get qActivity => 'روزهایت چقدر پرتحرک است؟';

  @override
  String get actSedentary => 'بی‌تحرک';

  @override
  String get actSedentaryDesc => 'بیشتر پشت میز، بدون ورزش';

  @override
  String get actLight => 'کم‌تحرک';

  @override
  String get actLightDesc => '۱ تا ۳ روز ورزش در هفته';

  @override
  String get actModerate => 'متوسط';

  @override
  String get actModerateDesc => '۳ تا ۵ روز ورزش در هفته';

  @override
  String get actActive => 'فعال';

  @override
  String get actActiveDesc => '۶ تا ۷ روز ورزش در هفته';

  @override
  String get actVeryActive => 'خیلی فعال';

  @override
  String get actVeryActiveDesc => 'کار بدنی همراه با ورزش';

  @override
  String get resultTitle => 'برنامه‌ی شخصی تو';

  @override
  String get resultDailyKcal => 'کالری روزانه‌ی تو';

  @override
  String get kcalUnit => 'کالری';

  @override
  String get macroProtein => 'پروتئین';

  @override
  String get macroCarbs => 'کربوهیدرات';

  @override
  String get macroFat => 'چربی';

  @override
  String gramsValue(String g) {
    return '$g گرم';
  }

  @override
  String resultEta(String weight, String date) {
    return 'رسیدن به $weight کیلو: حدود $date';
  }

  @override
  String resultEtaWeeks(String weeks) {
    return 'حدود $weeks هفته';
  }

  @override
  String get resultMaintain => 'هدف: حفظ وزن فعلی و تغذیه‌ی سالم';

  @override
  String get resultChartTitle => 'پیش‌بینی وزن';

  @override
  String get chartWeekAxis => 'هفته';

  @override
  String get resultStart => 'شروع کن';

  @override
  String get warnFloor =>
      'برای سلامتت، سرعت کمتری انتخاب کن. کالری روزانه روی حداقل ایمن ماند.';

  @override
  String get warnMinor =>
      'چون زیر ۱۸ سال هستی، برنامه‌ات «تغذیه‌ی سالم» است، نه کاهش وزن.';

  @override
  String get warnPregnancy => 'در دوران بارداری و شیردهی کالری کم نمی‌شود.';

  @override
  String get warnLowBmi =>
      'وزنت در محدوده‌ی کم است؛ برنامه روی حفظ وزن تنظیم شد.';

  @override
  String get warnConsultDoctor =>
      'پیش از هر تغییر در رژیم غذایی با پزشک مشورت کن.';

  @override
  String get profileSummary => 'برنامه‌ی فعلی';

  @override
  String get profileEdit => 'ویرایش پروفایل و هدف';

  @override
  String get profileSex => 'جنسیت';

  @override
  String get profileBirthDate => 'تاریخ تولد';

  @override
  String get profilePregnant => 'باردار یا شیرده';

  @override
  String get profileHeight => 'قد';

  @override
  String get profileCurrentWeight => 'وزن فعلی';

  @override
  String get profileGoal => 'هدف';

  @override
  String get profileGoalWeight => 'وزن هدف';

  @override
  String get profileRate => 'سرعت';

  @override
  String get profileActivity => 'سطح فعالیت';

  @override
  String get profileNoData => 'هنوز پروفایلی ثبت نشده است.';

  @override
  String editPreview(String kcal) {
    return 'کالری روزانه با این تغییرات: $kcal';
  }

  @override
  String get goToToday => 'برو به امروز';

  @override
  String get prevWeek => 'هفته‌ی قبل';

  @override
  String get nextWeek => 'هفته‌ی بعد';

  @override
  String get kcalConsumed => 'خورده‌شده';

  @override
  String get kcalRemaining => 'باقی‌مانده';

  @override
  String get kcalGoal => 'هدف';

  @override
  String kcalValue(String kcal) {
    return '$kcal کالری';
  }

  @override
  String kcalOver(String kcal) {
    return 'امروز $kcal کالری بیشتر شد؛ فردا جبرانش آسان است.';
  }

  @override
  String incompleteItems(String count) {
    return '$count مورد بدون داده‌ی کامل؛ جمع‌ها تقریبی‌اند.';
  }

  @override
  String get noGoal => 'هنوز هدفی تعیین نشده است.';

  @override
  String get mealBreakfast => 'صبحانه';

  @override
  String get mealLunch => 'ناهار';

  @override
  String get mealDinner => 'شام';

  @override
  String get mealSnack => 'میان‌وعده';

  @override
  String get mealEmpty => 'هنوز چیزی ثبت نشده';

  @override
  String addToMeal(String meal) {
    return 'افزودن به $meal';
  }

  @override
  String get water => 'آب';

  @override
  String waterGlasses(String count) {
    return '$count لیوان';
  }

  @override
  String get waterAdd => 'یک لیوان بیشتر';

  @override
  String get waterRemove => 'یک لیوان کمتر';

  @override
  String get searchHint => 'جستجوی غذا… (مثلاً قورمه‌سبزی)';

  @override
  String get searchNoResult => 'غذایی با این نام پیدا نشد.';

  @override
  String get sectionFavorites => 'علاقه‌مندی‌ها';

  @override
  String get sectionRecent => 'اخیر';

  @override
  String get sectionFrequent => 'پرتکرار';

  @override
  String get sectionAll => 'همه‌ی غذاها';

  @override
  String get dataIncomplete => 'داده ناقص';

  @override
  String get dataApprox => 'تقریبی';

  @override
  String get dataIncompleteHint =>
      'ارزش غذایی این غذا هنوز از منبع معتبر وارد نشده است. ثبت می‌شود، ولی در جمع کالری حساب نمی‌شود.';

  @override
  String get unitWeightUnknown =>
      'وزن این واحد هنوز اندازه‌گیری نشده است؛ «گرم» را انتخاب کن تا عدد دقیق ببینی.';

  @override
  String get quantity => 'مقدار';

  @override
  String get unit => 'واحد';

  @override
  String get meal => 'وعده';

  @override
  String logToMeal(String meal) {
    return 'ثبت در $meal';
  }

  @override
  String get logged => 'ثبت شد';

  @override
  String get deleteItem => 'حذف';

  @override
  String get deleteConfirm => 'این مورد حذف شود؟';

  @override
  String get deleted => 'حذف شد';

  @override
  String get favoriteAdd => 'افزودن به علاقه‌مندی‌ها';

  @override
  String get favoriteRemove => 'حذف از علاقه‌مندی‌ها';

  @override
  String get unknownFood => 'غذای ناشناخته';

  @override
  String get foodNotFound =>
      'این غذا در پایگاه داده نیست؛ فقط می‌توانی حذفش کنی.';

  @override
  String get noValue => '—';

  @override
  String get enterQuantity => 'مقدار را وارد کن';

  @override
  String get increase => 'بیشتر';

  @override
  String get decrease => 'کمتر';

  @override
  String get uKafgir => 'کفگیر';

  @override
  String get uLadle => 'ملاقه';

  @override
  String get uPlate => 'بشقاب';

  @override
  String get uBowl => 'کاسه';

  @override
  String get uGlass => 'لیوان';

  @override
  String get uTablespoon => 'قاشق غذاخوری';

  @override
  String get uPalm => 'کف دست';

  @override
  String get uPiece => 'عدد';

  @override
  String get uGram => 'گرم';

  @override
  String get uSlice => 'برش';

  @override
  String get month1 => 'فروردین';

  @override
  String get month2 => 'اردیبهشت';

  @override
  String get month3 => 'خرداد';

  @override
  String get month4 => 'تیر';

  @override
  String get month5 => 'مرداد';

  @override
  String get month6 => 'شهریور';

  @override
  String get month7 => 'مهر';

  @override
  String get month8 => 'آبان';

  @override
  String get month9 => 'آذر';

  @override
  String get month10 => 'دی';

  @override
  String get month11 => 'بهمن';

  @override
  String get month12 => 'اسفند';

  @override
  String get weekdaySat => 'شنبه';

  @override
  String get weekdayShortSat => 'ش';

  @override
  String get weekdaySun => 'یکشنبه';

  @override
  String get weekdayShortSun => 'ی';

  @override
  String get weekdayMon => 'دوشنبه';

  @override
  String get weekdayShortMon => 'د';

  @override
  String get weekdayTue => 'سه‌شنبه';

  @override
  String get weekdayShortTue => 'س';

  @override
  String get weekdayWed => 'چهارشنبه';

  @override
  String get weekdayShortWed => 'چ';

  @override
  String get weekdayThu => 'پنجشنبه';

  @override
  String get weekdayShortThu => 'پ';

  @override
  String get weekdayFri => 'جمعه';

  @override
  String get weekdayShortFri => 'ج';

  @override
  String dateLong(String day, String month, String year) {
    return '$day $month $year';
  }

  @override
  String dateWithWeekday(String weekday, String date) {
    return '$weekday $date';
  }

  @override
  String logSheetTitle(String meal) {
    return 'ثبت در $meal';
  }

  @override
  String get actionCamera => 'عکس';

  @override
  String get actionGallery => 'گالری';

  @override
  String get actionSearch => 'جستجو';

  @override
  String get actionVoice => 'صوتی';
}
