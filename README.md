# کالری‌لنز (نام موقت)

کالری‌شمار عکسی غذاهای ایرانی — Flutter، اندروید (کافه‌بازار و مایکت).

وضعیت: مرحله‌های **۰ تا ۶** انجام شده است. در مرحله‌ی ۵ منطق تبلیغات، اشتراک و سهمیه کامل است؛ اتصال SDK تپسل، بازار و مایکت بعد از ساخت حساب‌ها (پایین).

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

## اسکن عکس و سرور واسط

اسکن عکس از سرور واسط (`server/`) استفاده می‌کند؛ راه‌اندازی آن در `server/README.md`.

```bash
# سرور توسعه (ارائه‌دهنده‌ی جعلی):
cd server && VISION_PROVIDER=fake uvicorn app.main:app --port 8000

# اپ روی شبیه‌ساز (پیش‌فرض: http://10.0.2.2:8000):
flutter run --flavor bazaar
# روی گوشی واقعی یا سرور دیگر:
flutter run --flavor bazaar --dart-define=API_BASE_URL=http://IP-رایانه:8000
# بدون سرور، فقط برای دیدن UI:
flutter run --flavor bazaar --dart-define=FAKE_SCAN=true
```

نسخه‌ی release فقط با HTTPS به سرور وصل می‌شود (`--dart-define=API_BASE_URL=https://...`).

## درآمد: آنچه بعد از ساخت حساب‌ها باید وصل شود (مرحله‌ی ۵)

منطق کامل و تست‌شده است (قوانین تکرار تبلیغ در `lib/core/ads/ad_policy.dart`، Paywall، سهمیه و پاداش سمت سرور).
تا وقتی SDKها اضافه نشده‌اند: در debug تبلیغ و خرید **آزمایشی** فعال است (توکن `test-…`)،
در release تبلیغی نیست و پرداخت پیام «هنوز فعال نشده» می‌دهد.

| کار | کجا |
|---|---|
| SDK تپسل‌پلاس + `TapsellAdService` (پیاده‌سازی `AdService`) | `lib/core/ads/` و `adServiceProvider`؛ کلید با `--dart-define=TAPSELL_KEY=…` |
| Poolakey (بازار) و Myket Billing ← `BazaarBilling` و `MyketBilling` (پیاده‌سازی `BillingService`) | `lib/core/billing/` و `billingServiceProvider` (بر اساس Flavor) |
| ساخت محصولات `premium_monthly`، `premium_quarterly`، `premium_yearly` در پنل فروشگاه‌ها | باید با `PRODUCT_DAYS` سرور یکی باشد |
| اعتبارسنجی خرید با API توسعه‌دهنده‌ی بازار و مایکت | `server/app/billing/verifiers.py` و `PURCHASE_VERIFIER=stores` |
| تأیید پاداش ویدیو با callback تپسل (در صورت امکان) | `TrustingRewardVerifier` در همان فایل |
| بلاک دسته‌های نامناسب (قرص لاغری، شرط‌بندی) | پنل تپسل |

## تست و بررسی

```bash
flutter analyze
flutter test
cd server && pytest -q
```

پوشش تست: `flutter test --coverage` ← `coverage/lcov.info`.
آخرین اندازه‌گیری:

| بخش | پوشش |
|---|---|
| `lib/core` (منطق اصلی) | ٪۸۵ |
| `lib/features` | ٪۸۹ |
| `lib/data` (بدون کد تولیدی Drift) | ٪۷۸ |

فایل‌های کم‌پوشش `lib/core` فقط پوسته‌ی پلاگین‌های اندرویدی‌اند (اعلان، ویجت، گفتار، اشتراک‌گذاری) که در تست با Fake جایگزین می‌شوند.

## ساخت APK و انتشار

```bash
cp android/key.properties.example android/key.properties   # یک بار؛ راهنما داخل فایل
flutter build apk --release --flavor bazaar --split-per-abi --obfuscate \
  --split-debug-info=build/symbols/bazaar --dart-define=API_BASE_URL=https://...
```
خروجی: `build/app/outputs/flutter-apk/`. بدون `key.properties`، release با کلید debug امضا می‌شود (قابل انتشار نیست).
چک‌لیست کامل انتشار، ASO و اسکرین‌شات‌ها: [`docs/RELEASE.md`](docs/RELEASE.md).
صفحه‌ی حریم خصوصی برای لینک فروشگاه: `python server/tools/export_privacy.py` ← `docs/privacy.html`.

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
server/                  سرور واسط FastAPI (تشخیص، سهمیه، لاگ هزینه)
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
