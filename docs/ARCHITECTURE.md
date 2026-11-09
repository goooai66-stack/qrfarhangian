# معماری «حساب‌یار» — گام ۱

> حسابداری شخصی آفلاین‌محور برای بازار ایران (کافه‌بازار / مایکت).
> Kotlin · Jetpack Compose · Room · Clean Architecture + MVVM · minSdk 23

## ۱. لایه‌ها و ماژول‌ها

```
┌────────────────────────── :app (Android) ──────────────────────────┐
│  ui/        Compose screens + ViewModels (MVVM, StateFlow)          │
│  usecase/   ConfirmBankSmsUseCase …                                 │
│  data/      Room entities/DAOs, repositories, SharedPreferences     │
│  sms/       BroadcastReceiver, inbox import, notifications          │
│  ads/       AdProvider facade + PolicedAdProvider gate               │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ depends on
┌───────────────────────────────▼─────────── :domain (pure Kotlin/JVM)┐
│  sms/      BankSmsParser, OtpFilter, SelfTransferDetector, Bank     │
│  calendar/ JalaliDate (الگوریتم استاندارد کبیسه ۳۳ساله + جدول شکست) │
│  ledger/   LedgerMath — بازمحاسبه زمانی مانده                       │
│  calc/     AmountExpression — موتور کیبورد ماشین‌حساب              │
│  ads/      AdPolicy, Entitlements — قوانین جایگاه تبلیغات            │
│  money/ text/ rates/                                                 │
└──────────────────────────────────────────────────────────────────────┘
```

چرا ماژول `domain` جدا و بدون اندروید؟ چون حساس‌ترین منطق (پول، تاریخ، پیامک، قوانین تبلیغات)
باید روی JVM در چند میلی‌ثانیه تست شود. ۳۶ تست واحد در گام ۱ نوشته شده و همه پاس می‌شوند
(`./gradlew :domain:test`).

DI دستی است (`AppContainer` در `HesabyarApp.kt`): برای دوازده سینگلتون، Hilt فقط زمان بیلد و حجم APK اضافه می‌کند.

## ۲. ساختار پوشه‌ها

```
app/src/main/kotlin/ir/hesabyar/app/
├── HesabyarApp.kt                  Application + AppContainer (DI دستی)
├── MainActivity.kt                 بدون اسپلش/تبلیغ؛ معرفی حریم خصوصی در اجرای اول
├── ads/       AdProvider · PolicedAdProvider · NoAdProvider · FakeAdProvider · AdsController
├── data/
│   ├── local/ AppDatabase · DatabaseSeeder · entity/{Core,Planning}Entities · dao/*
│   ├── prefs/ AppPreferences (دفتر فعال، entitlements)
│   └── repository/ TransactionRepository · RatesRepository
├── sms/       SmsReceiver · SmsIngestor · SmsInboxImporter · SmsNotifier
├── usecase/   ConfirmBankSmsUseCase
└── ui/
    ├── theme/      Color · Type (Vazirmatn) · Theme (RTL اجباری، روشن/تیره)
    ├── components/ AppCard · CalculatorKeyboard · NativeAdCard · BannerSlot · RewardedUnlockDialog …
    ├── main/       MainScreen (۵ تب، مدیریت Back)
    ├── dashboard/  DashboardScreen · DashboardViewModel
    ├── transaction/ AddTransactionSheet · AddTransactionViewModel · JalaliDatePickerDialog
    ├── transactions/ TransactionsScreen (تبلیغ همسان هر ۱۰ ردیف)
    ├── tools/      ToolsScreen (تبلیغ همسان زیر نرخ‌ها) · ReportsScreen (بنر پایین) · DueDatesScreen
    └── onboarding/ PrivacyIntroScreen
domain/src/main/kotlin/ir/hesabyar/domain/   (بالا)
domain/src/test/kotlin/…                     BankSmsParserTest · JalaliDateTest · EngineTest
```

## ۳. دیتابیس (Room, نسخه ۱)

قراردادها: مبلغ همیشه `Long` به **ریال** (همان واحد پیامک بانک؛ نمایش به تومان)، زمان `epoch millis`،
روزِ تقویمی `epochDay`، enumها با نام ذخیره می‌شوند.

| جدول | نقش | نکات کلیدی |
|---|---|---|
| `ledgers` | دفترها (شخصی/کسب‌وکار) | ۲ رایگان، بیشتر با ویدیوی جایزه‌دار |
| `accounts` | حساب/کارت/نقد | `cardLast4`، `smsSender` (یادگیری فرستنده)، `openingBalanceRial`، کش `currentBalanceRial` |
| `categories` | دسته‌بندی | آیکون ایموجی (صفر بایت asset)، `matchKeywords` برای پیشنهاد از کانال پیامک |
| `transactions` | هر جابه‌جایی پول | `balanceAfterRial` بر اساس ترتیب زمانی؛ انتقال = دو ردیف `TRANSFER_OUT`/`TRANSFER_IN` با `transferGroupId` |
| `bank_sms` | صندوق پیامک تاییدنشده | `bodyHash` یکتا (ضدتکرار)، `selfTransferPairId`، وضعیت PENDING/CONFIRMED/DISMISSED/SELF_TRANSFER |
| `cheques` | چک صیادی | `sayadId` یکتای ۱۶ رقمی، `dueEpochDay`، وضعیت در جریان/پاس/برگشتی |
| `loans` · `installments` | وام و اقساط | شماره قسط (۱۲ از ۳۶)، روز سررسید شمسی، کسر خودکار |
| `people` · `debts` | طلب و بدهی، دنگ | `splitGroupId` برای سهم‌های یک صورتحساب |
| `savings_goals` · `savings_deposits` | پس‌انداز ضدتورم | هدف به گرم طلا/دلار/تتر (milli-unit صحیح)، قیمت واحد در روز واریز |
| `rates` | کش نرخ بازار | کار در حالت آفلاین با آخرین قیمت |

### رفع باگ «تاریخ گذشته»
`TransactionRepository.save()` هر حسابِ تحت‌تاثیر را از **زودترین لحظه‌ی تغییر** دوباره حساب می‌کند:
مانده‌ی آخرین ردیفِ قبل از آن لحظه + `LedgerMath.runningBalances` روی ردیف‌های بعدی به ترتیب
`(occurredAt, id)`. هزینه O(ردیف‌های بعد از تغییر)، نه O(کل). ویرایش تاریخ، حذف و انتقال هم همین مسیر را می‌روند.

## ۴. موتور پیامک بانکی

```
SMS ─► normalize ─► OTP? ─► ناموفق? ─► تشخیص بانک ─► مبلغ/علامت/واحد ─► مانده ─► حساب ─► تاریخ شمسی ─► جهت/کانال/اطمینان
         (۱۲۳/١٢٣/ي/ك/٬/RLM)   drop      drop                     (ریال/تومان)
```

* **برچسب‌محور، نه قالب‌محور**: به‌جای یک regex شکننده برای هر بانک، واژگان برچسب‌ها
  (`برداشت`، `واریز`، `مبلغ`، `مانده`، `حساب`، `کارت`…) با ترتیب و شکل آزاد خوانده می‌شوند. ویژگی‌های
  خاص بانک‌ها (علامت انتهایی `1,000,000-` صادرات، تاریخ `0815-14:23` ملی، واحد تومان نئوبانک‌ها،
  سال دورقمی `03/08/15`) به‌صورت حالت‌های عمومی پوشش داده شده‌اند.
* **«مانده قابل برداشت»** هرگز به‌عنوان برداشت خوانده نمی‌شود (بخش مانده قبل از جستجوی کلمات حذف می‌شود).
* **فیلتر رمز پویا** قبل از هر ذخیره‌سازی؛ پیامک OTP حتی در بکاپ هم وجود نخواهد داشت.
* **انتقال بین حساب‌های خود**: برداشت از حساب A و واریز هم‌مبلغ به حساب B (A≠B) در بازه‌ی ۲ دقیقه،
  به هر ترتیب ⇒ یک کارت «انتقال بین حساب‌های شما» که در درآمد/هزینه شمرده نمی‌شود.
* **ساخت خودکار حساب**: اولین پیامک یک کارت ناشناخته، حساب را می‌سازد و اگر پیامک مانده داشته باشد
  موجودی اولیه را معکوس محاسبه می‌کند تا پس از تایید، موجودی اپ با بانک تا ریال برابر باشد.
* شماره‌ی فرستنده‌ی بانک‌ها هاردکد نشده (بین اپراتورها فرق دارد)؛ پس از اولین تایید، اپ فرستنده→حساب را یاد می‌گیرد.

**نیاز قطعی پیش از انتشار:** نمونه پیامک‌های واقعی (با ارقام ماسک‌شده) از هر بانک را به
`BankSmsParserTest` اضافه کنید. نمونه‌های فعلی ساختار عمومی پیامک بانک‌ها را بازسازی کرده‌اند، نه متن عینی آن‌ها را.

## ۵. سیاست تبلیغات (`domain/ads/AdPolicy.kt`)

همه‌ی تصمیم‌ها در یک جا و با تست؛ `PolicedAdProvider` جلوی هر SDK می‌ایستد تا حتی یک صفحه‌ی باگ‌دار هم نتواند قانون را بشکند.

| سطح | Native | Banner | Rewarded (فقط با لمس کاربر) | Interstitial / App-open |
|---|---|---|---|---|
| شروع برنامه، قفل، فرم ثبت، کیبورد، تایید پیامک، هشدار سررسید، معرفی | ✗ | ✗ | ✗ | ✗ |
| داشبورد | ✗ | ✗ | ✓ (مثلاً دستیار صوتی) | ✗ |
| تراکنش‌ها | ✓ هر ۱۰ ردیف | ✗ | ✓ | ✗ |
| ابزارها | ✓ زیر جدول نرخ | ✗ | ✓ | ✗ |
| ماشین‌حساب طلا / وام | ✗ | ✓ پایین صفحه | ✗ | ✗ |
| گزارش‌ها | ✗ | ✓ پایین صفحه | ✓ (خروجی Excel/PDF) | ✗ |

جوایز: خروجی Excel/PDF = ۱ اعتبار به ازای هر ویدیو · دستیار صوتی و سپر ضدتورم = ۲۴ ساعت (قابل انباشت) ·
دفتر اضافه = +۱ دائمی. اگر شبکه تبلیغی ویدیو نداشت (`NO_FILL`)، قابلیت رایگان باز می‌شود — کاربر جریمه نمی‌شود.

## ۶. ناوبری و Back

* هر تب غیر از داشبورد ← Back ← داشبورد.
* داشبورد ← Back دوبار در ۲ ثانیه برای خروج، با Toast «برای خروج دوباره ضربه بزنید».
* Bottom sheet و دیالوگ‌ها در پنجره‌ی خودشان Back را مصرف می‌کنند و فقط خودشان بسته می‌شوند.

## ۷. حجم APK (هدف < ۱۵MB)

فونت Vazirmatn UI-FD-NL (سه وزن، ~۱۶۵KB)، آیکون‌های دسته‌بندی ایموجی، بدون
`material-icons-extended` (چند آیکون لازم دستی ساخته شده)، بدون Hilt/Navigation/DataStore، R8 + shrinkResources،
فقط منابع `fa`. برآورد فعلی بدون SDK تبلیغ: حدود ۴ تا ۶ مگابایت. SDK تبلیغاتی بزرگ‌ترین ریسک حجم است.

## ۸. نقشه‌ی گام‌های بعد

| گام | محتوا |
|---|---|
| ۲ | تب سررسیدها: تقویم شمسی، چک صیادی، اقساط، دنگ، یادآور ۳/۱/۰ روز با AlarmManager · فیلترهای پیشرفته‌ی تراکنش · دستیار صوتی فارسی |
| ۳ | منبع نرخ زنده + ماشین‌حساب طلای ۱۸ عیار (اجرت، سود ≤۷٪، مالیات ۹٪ روی اجرت+سود) · وام (فرمول قدیم/جدید) · پس‌انداز ضدتورم |
| ۴ | آداپتورهای Tapsell Mediation / Adivery روی `AdProvider` + قوانین ProGuard |
| ۵ | گزارش و نمودار · خروجی Excel/PDF فارسی · بکاپ رمزنگاری‌شده و اشتراک · قفل اثر انگشت/PIN · شروع سال مالی جدید |
