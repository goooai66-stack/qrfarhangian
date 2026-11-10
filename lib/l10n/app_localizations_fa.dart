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
  String get unitKgShort => 'کیلو';

  @override
  String get unitLb => 'پوند';

  @override
  String get weightUnitTitle => 'واحد وزن';

  @override
  String kgValue(String value, String unit) {
    return '$value $unit';
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
  String goalWeightRange(String min, String max, String unit) {
    return 'بین $min تا $max $unit';
  }

  @override
  String goalWeightDiff(String amount, String unit) {
    return 'تغییر: $amount $unit';
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
  String rateValue(String amount, String unit) {
    return '$amount $unit در هفته';
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
  String resultEta(String weight, String unit, String date) {
    return 'رسیدن به $weight $unit: حدود $date';
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

  @override
  String get scanGuideTitle => 'راهنمای عکس گرفتن';

  @override
  String get scanGuide1 => 'بشقاب را از بالا و کامل در کادر بگیر.';

  @override
  String get scanGuide2 => 'نور کافی باشد و سایه روی غذا نیفتد.';

  @override
  String get scanGuide3 =>
      'قاشق یا دست کنار بشقاب، به تخمین اندازه کمک می‌کند.';

  @override
  String get scanGuideOk => 'متوجه شدم، عکس بگیر';

  @override
  String get analyzing => 'در حال تحلیل…';

  @override
  String get scanTip1 => 'آب را قبل از غذا بنوش؛ به حس سیری کمک می‌کند.';

  @override
  String get scanTip2 => 'پروتئین کافی در هر وعده، گرسنگی را دیرتر می‌کند.';

  @override
  String get scanTip3 => 'آهسته غذا خوردن به بدن فرصت می‌دهد سیری را حس کند.';

  @override
  String get scanTip4 =>
      'سبزی خوردن و سالاد کنار غذا، بشقاب را پرتر و سبک‌تر می‌کند.';

  @override
  String get scanTip5 => 'ته‌دیگ خوشمزه است؛ فقط حواست به اندازه‌اش باشد!';

  @override
  String get scanResultTitle => 'نتیجه‌ی تشخیص';

  @override
  String get scanLowConfidence => 'مطمئن نیستیم، لطفاً بررسی کن.';

  @override
  String get scanNotFound => 'این غذا را پیدا نکردیم، انتخاب کن.';

  @override
  String get scanChooseFood => 'انتخاب غذا';

  @override
  String get scanChangeFood => 'تغییر غذا';

  @override
  String get scanAddMissing => 'افزودن آیتم جاافتاده';

  @override
  String scanDetected(String name) {
    return 'تشخیص: $name';
  }

  @override
  String get scanNoItems =>
      'هیچ آیتمی نمانده. یک غذا اضافه کن یا عکس دیگری بگیر.';

  @override
  String scanUnitAdjusted(String unit) {
    return 'واحد به $unit تغییر کرد.';
  }

  @override
  String get scanNotFood => 'غذایی در عکس پیدا نشد.';

  @override
  String get scanNotFoodHint =>
      'سهمیه‌ات کم نشد. دوباره امتحان کن یا دستی ثبت کن.';

  @override
  String get scanOfflineTitle => 'اینترنت نیست';

  @override
  String get scanOfflineQueued => 'عکس ذخیره شد؛ وقتی وصل شدی تحلیلش می‌کنیم.';

  @override
  String get scanTimeout => 'پاسخ دیر رسید. دوباره امتحان کن.';

  @override
  String get scanBusy => 'سرور شلوغ است. کمی بعد دوباره امتحان کن.';

  @override
  String get scanRateLimited => 'چند اسکن پشت سر هم زدی؛ یک دقیقه صبر کن.';

  @override
  String get scanBadImage => 'این عکس قابل استفاده نیست. عکس دیگری انتخاب کن.';

  @override
  String get scanError => 'تشخیص انجام نشد. دوباره امتحان کن.';

  @override
  String get scanQuotaTitle => 'سهمیه‌ی اسکن امروز تمام شد';

  @override
  String get scanQuotaHint =>
      'فردا سهمیه‌ی رایگانت دوباره پر می‌شود. تا آن موقع می‌توانی دستی ثبت کنی.';

  @override
  String get scanQuotaVideo => '🎬 دیدن یک ویدیو = ۱ اسکن';

  @override
  String get scanQuotaPremium => '💎 اسکن نامحدود';

  @override
  String get retry => 'دوباره';

  @override
  String get manualLog => 'ثبت دستی';

  @override
  String get takeAnother => 'عکس دیگر';

  @override
  String pendingReady(String count) {
    return '$count عکس آماده‌ی بررسی است';
  }

  @override
  String pendingQueued(String count) {
    return '$count عکس در صف تحلیل (بعد از وصل شدن)';
  }

  @override
  String get review => 'بررسی';

  @override
  String get discard => 'کنار بگذار';

  @override
  String confidenceValue(String percent) {
    return 'اطمینان $percent٪';
  }

  @override
  String get streakTitle => 'زنجیره‌ی روزهای پیاپی';

  @override
  String streakDays(String n) {
    return '$n روز پیاپی';
  }

  @override
  String streakRecord(String n) {
    return 'رکورد: $n روز';
  }

  @override
  String get streakZero => 'امروز یک غذا ثبت کن تا زنجیره شروع شود.';

  @override
  String get weightTitle => 'وزن';

  @override
  String get logWeight => 'ثبت وزن';

  @override
  String get weightStart => 'شروع';

  @override
  String get weightCurrent => 'فعلی';

  @override
  String get weightGoalLabel => 'هدف';

  @override
  String weightChangeFromStart(String amount, String unit) {
    return 'تغییر از شروع: $amount $unit';
  }

  @override
  String get noWeights => 'هنوز وزنی ثبت نشده.';

  @override
  String get deleteWeightConfirm => 'این ثبت وزن حذف شود؟';

  @override
  String get caloriesTitle => 'کالری روزانه';

  @override
  String get range7 => '۷ روز';

  @override
  String get range30 => '۳۰ روز';

  @override
  String avgKcal(String kcal) {
    return 'میانگین روزهای ثبت‌شده: $kcal کالری';
  }

  @override
  String avgMacros(String p, String c, String f) {
    return 'میانگین پروتئین $p، کربوهیدرات $c، چربی $f گرم';
  }

  @override
  String get noLogsRange => 'در این بازه چیزی ثبت نشده.';

  @override
  String get badgesTitle => 'نشان‌ها';

  @override
  String get badgeFirstLog => 'اولین ثبت';

  @override
  String get badgeFirstLogDesc => 'اولین غذایت را ثبت کردی';

  @override
  String get badgeStreak3 => '۳ روز پیاپی';

  @override
  String get badgeStreak3Desc => 'سه روز پشت سر هم ثبت کردی';

  @override
  String get badgeStreak7 => '۷ روز پیاپی';

  @override
  String get badgeStreak7Desc => 'یک هفته‌ی کامل، بدون وقفه';

  @override
  String get badgeFirstKg => 'اولین کیلو';

  @override
  String get badgeFirstKgDesc => 'اولین کیلو در مسیر هدفت';

  @override
  String get badgeWater8 => '۸ لیوان آب';

  @override
  String get badgeWater8Desc => 'یک روز کامل آب کافی نوشیدی';

  @override
  String get badgeLocked => 'هنوز نه';

  @override
  String get beforeAfterTitle => 'عکس قبل و بعد';

  @override
  String get beforeAfterPrivacy =>
      'این عکس‌ها فقط روی گوشی خودت می‌مانند و هرگز آپلود نمی‌شوند.';

  @override
  String get photoBefore => 'قبل';

  @override
  String get photoAfter => 'بعد';

  @override
  String get addPhoto => 'افزودن عکس';

  @override
  String get removePhoto => 'حذف عکس';

  @override
  String get shareCard => 'ساخت کارت اشتراک';

  @override
  String get shareStreak => 'اشتراک زنجیره';

  @override
  String get shareNow => 'اشتراک‌گذاری';

  @override
  String get cardStreak => 'روز پیاپی';

  @override
  String cardWeightChange(String amount, String unit, String days) {
    return '$amount $unit در $days روز';
  }

  @override
  String get cardTagline => 'کالری شمار با عکس، برای غذای ایرانی';

  @override
  String get shareText => 'مسیرم را با کالری‌لنز ثبت می‌کنم 💪';

  @override
  String get remindersTitle => 'یادآورها';

  @override
  String get remindMeals => 'یادآور وعده‌ها';

  @override
  String get remindWater => 'یادآور آب';

  @override
  String remindWaterEvery(String n, String from, String to) {
    return 'هر $n ساعت، از $from تا $to';
  }

  @override
  String get remindWeight => 'یادآور ثبت وزن (هفتگی)';

  @override
  String get remindPermissionDenied =>
      'اجازه‌ی اعلان داده نشد. از تنظیمات گوشی فعالش کن.';

  @override
  String get remindSaved => 'یادآورها تنظیم شد';

  @override
  String get notifBreakfastTitle => 'وقت صبحانه 🍳';

  @override
  String get notifBreakfastBody => 'صبحانه‌ات را با یک عکس ثبت کن.';

  @override
  String get notifLunchTitle => 'وقت ناهار 🍛';

  @override
  String get notifLunchBody => 'ناهار امروز چی بود؟ یک عکس کافی است.';

  @override
  String get notifDinnerTitle => 'وقت شام 🌙';

  @override
  String get notifDinnerBody => 'شامت را ثبت کن تا روزت کامل شود.';

  @override
  String get notifWaterTitle => 'یک لیوان آب 💧';

  @override
  String get notifWaterBody => 'بدنت از آب کافی تشکر می‌کند.';

  @override
  String get notifWeightTitle => 'ثبت وزن هفتگی ⚖️';

  @override
  String get notifWeightBody =>
      'وزن این هفته را ثبت کن؛ هر عددی باشد، قدمی در مسیر است.';

  @override
  String get widgetRemaining => 'کالری باقی‌مانده';

  @override
  String get widgetOver => 'بیشتر از هدف امروز';

  @override
  String widgetDetail(String consumed, String goal) {
    return '$consumed از $goal کالری';
  }

  @override
  String get rateTitle => 'از کالری‌لنز راضی هستی؟';

  @override
  String rateBody(String store) {
    return 'اگر کمکت کرده، با امتیاز دادن در $store به ما کمک کن تا بهتر شویم.';
  }

  @override
  String get rateYes => 'امتیاز می‌دهم';

  @override
  String get rateLater => 'بعداً';

  @override
  String get rateNever => 'نه، ممنون';

  @override
  String get storeBazaar => 'کافه‌بازار';

  @override
  String get storeMyket => 'مایکت';

  @override
  String get storeGeneric => 'فروشگاه';

  @override
  String get adLabel => 'تبلیغ';

  @override
  String get premiumTitle => 'کالری‌لنز ویژه 💎';

  @override
  String get premiumBenefitScan => 'اسکن نامحدود عکس (سقف منصفانه‌ی ۳۰ در روز)';

  @override
  String get premiumBenefitNoAds => 'بدون هیچ تبلیغی';

  @override
  String get premiumBenefitMore => 'امکانات ویژه‌ی بعدی هم برای تو باز می‌شوند';

  @override
  String get planMonthly => 'ماهانه';

  @override
  String get planQuarterly => 'سه‌ماهه';

  @override
  String get planYearly => 'سالانه';

  @override
  String get bestValue => 'به‌صرفه‌ترین';

  @override
  String get priceInStore => 'قیمت در فروشگاه';

  @override
  String get buy => 'خرید';

  @override
  String get notNow => 'فعلاً نه';

  @override
  String get restorePurchases => 'بازیابی خرید';

  @override
  String get purchaseSuccess => 'اشتراک ویژه فعال شد 💎';

  @override
  String get purchaseUnavailable => 'پرداخت هنوز فعال نشده است.';

  @override
  String get purchaseFailed =>
      'خرید تأیید نشد. اگر مبلغی کم شده، «بازیابی خرید» را بزن.';

  @override
  String get restoreNone => 'خریدی برای بازیابی پیدا نشد.';

  @override
  String premiumActiveUntil(String date) {
    return 'ویژه تا $date';
  }

  @override
  String get upgradePremium => 'ارتقا به ویژه 💎';

  @override
  String get rewardGranted => '۱ اسکن به سهمیه‌ات اضافه شد';

  @override
  String get rewardNotCompleted => 'ویدیو کامل دیده نشد؛ اسکنی اضافه نشد.';

  @override
  String get rewardUnavailable => 'الان ویدیویی برای نمایش نیست.';

  @override
  String get rewardLimit => 'سقف ویدیوی امروز پر شده است.';

  @override
  String get rewardFailed => 'ثبت پاداش انجام نشد. دوباره امتحان کن.';

  @override
  String get mealSuhoor => 'سحر';

  @override
  String get mealIftar => 'افطار';

  @override
  String get ramadanMode => 'حالت رمضان';

  @override
  String get ramadanModeDesc =>
      'سحر و افطار به‌جای صبحانه و شام؛ یادآور آب بین افطار و سحر';

  @override
  String get notifSuhoorTitle => 'وقت سحر 🌙';

  @override
  String get notifSuhoorBody => 'سحری‌ات را ثبت کن؛ آب کافی هم یادت نرود.';

  @override
  String get notifIftarTitle => 'افطار 🌅';

  @override
  String get notifIftarBody => 'قبول باشد! افطارت را با یک عکس ثبت کن.';

  @override
  String get voiceTitle => 'ثبت صوتی یا متنی';

  @override
  String get voiceHold => 'نگه دار و بگو';

  @override
  String get voiceListening => 'در حال شنیدن…';

  @override
  String get voiceHint => 'مثلاً: «ناهار یه بشقاب قیمه با برنج و یه دوغ خوردم»';

  @override
  String get voiceTypeHint => 'یا اینجا بنویس…';

  @override
  String get voiceSend => 'ثبت';

  @override
  String get voiceUnavailable =>
      'تشخیص گفتار روی این گوشی در دسترس نیست؛ جمله را تایپ کن.';

  @override
  String get voiceNotFood => 'در این جمله غذایی پیدا نشد. دوباره بگو یا بنویس.';

  @override
  String get voiceQuota =>
      'سهمیه‌ی ثبت صوتی امروز تمام شد. ثبت دستی همیشه رایگان است.';

  @override
  String get customMeals => 'غذاهای ترکیبی من';

  @override
  String get saveAsCustomMeal => 'ذخیره به‌عنوان غذای ترکیبی';

  @override
  String get customMealName => 'نام غذای ترکیبی';

  @override
  String get customMealNameHint => 'مثلاً «صبحانه‌ی همیشگی»';

  @override
  String customMealSaved(String name) {
    return '«$name» ذخیره شد';
  }

  @override
  String customMealItems(String n) {
    return '$n قلم';
  }

  @override
  String customMealLogged(String n) {
    return '$n قلم ثبت شد';
  }

  @override
  String customMealDeleteConfirm(String name) {
    return '«$name» حذف شود؟';
  }

  @override
  String get copyYesterday => 'کپی از دیروز';

  @override
  String copiedYesterday(String n) {
    return '$n قلم از دیروز کپی شد';
  }

  @override
  String get nothingYesterday => 'دیروز در این وعده چیزی ثبت نشده.';

  @override
  String get inviteTitle => 'دعوت از دوستان';

  @override
  String inviteDesc(String days) {
    return 'هر دوستی که با کد تو بیاید، هر دوی شما $days روز ویژه می‌گیرید.';
  }

  @override
  String get inviteYourCode => 'کد دعوت تو';

  @override
  String get inviteCopied => 'کد کپی شد';

  @override
  String get inviteShare => 'ارسال برای دوستان';

  @override
  String inviteShareText(String code, String days) {
    return 'کالری‌لنز رو نصب کن و کد $code رو وارد کن؛ هر دومون $days روز ویژه می‌گیریم 🎁';
  }

  @override
  String inviteCount(String n) {
    return '$n دوست با کد تو آمده‌اند';
  }

  @override
  String get inviteEnter => 'کد دعوت داری؟';

  @override
  String get inviteRedeem => 'ثبت کد';

  @override
  String get inviteRedeemed => 'هدیه فعال شد 🎁';

  @override
  String get inviteInvalid => 'این کد پیدا نشد.';

  @override
  String get inviteOwn => 'کد خودت را نمی‌توانی وارد کنی.';

  @override
  String get inviteAlready => 'قبلاً یک کد دعوت وارد کرده‌ای.';

  @override
  String get inviteOffline => 'برای دعوت به اینترنت نیاز است.';

  @override
  String get wrongDetection => 'تشخیص اشتباه بود؟';

  @override
  String get wrongDetectionTitle => 'گزارش تشخیص اشتباه';

  @override
  String get wrongDetectionHint =>
      'اصلاحاتی که در فهرست کردی همراه گزارش فرستاده می‌شود (بدون عکس). اگر توضیحی داری بنویس:';

  @override
  String get wrongDetectionSend => 'ارسال گزارش';

  @override
  String get wrongDetectionThanks =>
      'ممنون! برای بهتر شدن تشخیص استفاده می‌شود.';

  @override
  String get aboutTitle => 'درباره‌ی کالری‌لنز';

  @override
  String aboutVersion(String version) {
    return 'نسخه‌ی $version';
  }

  @override
  String get aboutTagline => 'کالری‌شمار عکسی غذاهای ایرانی';

  @override
  String get privacyTitle => 'حریم خصوصی';

  @override
  String get disclaimerTitle => 'سلب مسئولیت پزشکی';

  @override
  String get disclaimerBody =>
      'کالری‌لنز ابزاری برای آگاهی از تغذیه است و جایگزین پزشک، متخصص تغذیه یا مشاوره‌ی درمانی نیست.\n\n• همه‌ی اعداد (کالری، درشت‌مغذی‌ها، وزن هدف و زمان رسیدن به آن) تخمینی‌اند. تشخیص غذا از عکس یا جمله ممکن است اشتباه باشد؛ همیشه نتیجه را بررسی کن.\n• محاسبه‌ی کالری روزانه با فرمول عمومی Mifflin-St Jeor انجام می‌شود و شرایط خاص بدن تو را در نظر نمی‌گیرد.\n• کالری روزانه هرگز کمتر از ۱۲۰۰ (زن) و ۱۵۰۰ (مرد) پیشنهاد نمی‌شود.\n• برای زیر ۱۸ سال، دوران بارداری و شیردهی، و کسانی که بیماری (مثل دیابت، بیماری قلبی یا کلیوی) یا سابقه‌ی اختلال خوردن دارند، پیش از هر تغییر در رژیم غذایی حتماً با پزشک مشورت کن.\n• اگر هنگام رژیم احساس ضعف، سرگیجه یا مشکل دیگری داشتی، رژیم را متوقف کن و به پزشک مراجعه کن.';

  @override
  String get privacyBody =>
      'ما به حریم خصوصی تو احترام می‌گذاریم. خلاصه: بیشتر داده‌هایت فقط روی گوشی خودت است.\n\n۱. داده‌هایی که فقط روی گوشی می‌مانند\nپروفایل (سن، قد، وزن، هدف)، غذاهای ثبت‌شده، وزن‌ها، آب، یادآورها، عکس‌های غذا (برای نمایش کوچک کنار ثبت‌ها) و عکس‌های «قبل و بعد». عکس‌های قبل و بعد هرگز آپلود نمی‌شوند.\n\n۲. داده‌هایی که به سرور ما فرستاده می‌شود\n• شناسه‌ی تصادفی دستگاه: هنگام اولین استفاده ساخته می‌شود و به نام، شماره یا ایمیل تو ربطی ندارد.\n• عکس غذا هنگام اسکن: برای تشخیص فرستاده می‌شود و ذخیره نمی‌شود. فقط نتیجه‌ی تشخیص (بدون عکس) تا ۷ روز برای سرعت بیشتر نگه داشته می‌شود.\n• متن جمله در ثبت صوتی یا متنی: صدا روی گوشی به متن تبدیل می‌شود و فقط متن به سرور می‌آید. سرویس گفتار گوشی (معمولاً Google) ممکن است صدا را طبق سیاست خودش پردازش کند.\n• گزارش «تشخیص اشتباه بود»: فهرست اصلاح‌شده‌ی غذاها و توضیح تو، بدون عکس.\n• تعداد استفاده‌ی روزانه (برای سهمیه)، کد دعوت و اطلاعات خرید اشتراک (برای اعتبارسنجی در فروشگاه).\n• آمار ناشناس استفاده (مثل «یک اسکن انجام شد»)، بدون هیچ داده‌ی شخصی یا غذایی. می‌توانی آن را در همین صفحه خاموش کنی.\n\n۳. سرویس‌های دیگر\n• تشخیص غذا و فهم جمله را یک سرویس هوش مصنوعی ([نام ارائه‌دهنده]) انجام می‌دهد؛ عکس یا متن فقط برای همین کار به آن فرستاده می‌شود.\n• پرداخت از طریق کافه‌بازار یا مایکت انجام می‌شود؛ ما اطلاعات کارت بانکی تو را نمی‌بینیم.\n• در نسخه‌ی رایگان، تبلیغات از طریق تپسل نمایش داده می‌شود که ممکن است شناسه‌ی تبلیغاتی گوشی را طبق سیاست خودش استفاده کند.\n\n۴. حذف داده‌ها\nبا «حذف همه‌ی داده‌ها» در تنظیمات، همه‌ی داده‌های روی گوشی و داده‌های این دستگاه روی سرور پاک می‌شود. فقط سابقه‌ی خرید اشتراک (بدون ارتباط با دستگاه) برای امکان «بازیابی خرید» باقی می‌ماند.\n\n۵. کودکان\nبرای کاربران زیر ۱۸ سال، هدف کاهش وزن غیرفعال است و فقط «تغذیه‌ی سالم» پیشنهاد می‌شود.\n\n۶. تماس\nپرسش یا درخواست: [ایمیل یا آیدی پشتیبانی]';

  @override
  String get licenses => 'مجوزهای نرم‌افزار';

  @override
  String get analyticsToggle => 'ارسال آمار ناشناس استفاده';

  @override
  String get analyticsToggleDesc =>
      'فقط شمارش رویدادها (مثل «یک اسکن»)، بدون داده‌ی شخصی؛ برای بهتر شدن اپ';

  @override
  String get deleteAllData => 'حذف همه‌ی داده‌ها';

  @override
  String get deleteAllDesc =>
      'همه‌ی ثبت‌ها، وزن‌ها، عکس‌ها و تنظیمات روی گوشی، و داده‌های این دستگاه روی سرور پاک می‌شود. این کار برگشت‌پذیر نیست.';

  @override
  String get deleteAllConfirm => 'برای تأیید، کلمه‌ی «حذف» را بنویس:';

  @override
  String get deleteAllWord => 'حذف';

  @override
  String get deleteAllDone => 'همه‌ی داده‌ها پاک شد.';

  @override
  String get deleteAllServerFailed =>
      'داده‌های گوشی پاک شد، ولی اتصال به سرور برقرار نشد؛ داده‌های این دستگاه روی سرور (فقط آمار استفاده) باقی ماند.';

  @override
  String get openSettingsInfo => 'درباره، حریم خصوصی و داده‌ها';

  @override
  String get serverUrlTitle => 'آدرس سرور';

  @override
  String get serverUrlNotSet => 'وارد نشده؛ اسکن و ثبت صوتی کار نمی‌کند';

  @override
  String get serverUrlHint => 'آدرسی که مدیر اپ به تو داده، مثل api.example.ir';

  @override
  String get serverUrlInvalid =>
      'آدرس درست نیست. باید یک آدرس امن (https) باشد.';

  @override
  String get serverUrlUnreachable =>
      'به این آدرس وصل نشدم یا سرور کالری‌لنز نیست. آدرس و اینترنت را بررسی کن.';

  @override
  String get serverUrlSaved => 'به سرور وصل شد و ذخیره شد.';

  @override
  String get serverUrlCheck => 'بررسی و ذخیره';

  @override
  String get serverUrlChecking => 'در حال بررسی…';
}
