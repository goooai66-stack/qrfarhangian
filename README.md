# کالری‌لنز (نام موقت)

کالری‌شمار عکسی غذاهای ایرانی — Flutter، اندروید (کافه‌بازار و مایکت).

وضعیت: **مرحله‌ی ۰ (اسکلت)، ۱ (آنبوردینگ و هدف) و ۲ (پایگاه غذا، ثبت دستی، داشبورد)** انجام شده است.

## پیش‌نیازها

- Flutter stable (ساخته‌شده با 3.47.9 / Dart 3.13)
- Android SDK (برای ساخت APK) و JDK 17 یا بالاتر

## اجرا

```bash
flutter pub get
dart run build_runner build      # تولید کد Drift (lib/data/db/app_database.g.dart)
flutter gen-l10n                 # تولید کلاس ترجمه از lib/l10n/app_fa.arb

# اجرا روی گوشی — حتماً flavor را بدهید:
flutter run --flavor bazaar
flutter run --flavor myket
```

## تست و بررسی

```bash
flutter analyze
flutter test
```

## ساخت APK

```bash
flutter build apk --release --flavor bazaar --split-per-abi
flutter build apk --release --flavor myket  --split-per-abi
```
خروجی: `build/app/outputs/flutter-apk/`.
امضای release فعلاً با کلید debug است؛ امضای واقعی در مرحله‌ی ۷.

## ساختار

```
lib/
  app/          روتر (go_router)، تم روشن/تیره، Flavor، providerها (Riverpod)
  core/
    utils/      ارقام فارسی، نرمال‌سازی متن فارسی، تاریخ شمسی
    nutrition/  BMR، TDEE، کالری هدف، درشت‌مغذی‌ها، قوانین ایمنی (با تست)
    ads/        AdService + FakeAdService
    billing/    BillingService + FakeBillingService
    recognition/ FoodRecognizer + FakeFoodRecognizer + OnDeviceRecognizer (خالی)
  data/db/      Drift: جدول‌های بخش ۱۰-۳، طرح نسخه‌ی ۱
  data/profile/ ProfileRepository: پروفایل، تاریخچه‌ی هدف، وزن فعلی
  data/foods/   FoodRepository: بارگذاری foods.json + جستجوی فازی فارسی
  data/logs/    FoodLogRepository: ثبت غذا، اخیر/پرتکرار، علاقه‌مندی، آب
  features/     آنبوردینگ، صفحه‌ی نتیجه، پروفایل و ویرایش آن، ۴ تب
  l10n/         app_fa.arb — همه‌ی متن‌های رابط کاربری اینجا
assets/
  data/foods.json        پایگاه غذا (فعلاً ۲۰ نمونه با مقادیر null)
  fonts/Vazirmatn/       Regular/Medium/Bold — مجوز OFL (OFL.txt)
server/                  (مرحله‌ی ۳)
```

## جایگزین کردن پایگاه غذا

فایل `assets/data/foods.json` را با داده‌ی واقعی (ساختار بخش ۷-۱ سند) جایگزین کنید.
- مقداری که از منبع ندارید `null` بماند؛ اپ کنارش «داده ناقص» نشان می‌دهد و در جمع کالری حسابش نمی‌کند.
- `verified: false` ← اپ «تقریبی» نشان می‌دهد.
- بعد از جایگزینی `flutter test test/data/foods` را اجرا کنید (ساختار، شناسه‌ی تکراری، جستجو).

## قراردادها

- متن مستقیم در کد ممنوع؛ همه در `lib/l10n/app_fa.arb` (از جمله نام ماه‌ها و روزهای شمسی و ترتیب اجزای تاریخ؛ `lib/l10n/date_names.dart`).
- نمایش با ارقام فارسی (`formatPersianNumber`)، ذخیره با ارقام لاتین.
- تاریخ: نمایش شمسی، ذخیره UTC؛ هفته از شنبه.
- هر تغییر جدول دیتابیس: `schemaVersion` را بالا ببرید و گام مهاجرت بنویسید.
