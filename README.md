# حساب‌یار — Hesabyar

حسابداری شخصی خودکار و آفلاین‌محور برای اندروید (بازار ایران): ثبت خودکار تراکنش از پیامک بانکی،
مدیریت چک و اقساط، ماشین‌حساب طلا و پس‌انداز ضدتورم.

* **Kotlin + Jetpack Compose + Room**، Clean Architecture + MVVM، minSdk 23 (Android 6)
* ۱۰۰٪ Local-First: بدون ثبت‌نام، داده و پیامک فقط روی گوشی
* فارسی، راست‌به‌چپ، تقویم شمسی دقیق، فونت Vazirmatn با ارقام فارسی

## ساخت و اجرا

```bash
./gradlew :domain:test        # تست‌های موتور (پیامک، تقویم، مانده، ماشین‌حساب، تبلیغات)
./gradlew :app:assembleDebug  # نیاز به Android SDK 35
```

در بیلد debug، `FakeAdProvider` همه‌ی جایگاه‌های تبلیغ را با نمونه نشان می‌دهد؛ بیلد release تا وصل شدن SDK تبلیغی هیچ تبلیغی ندارد.

## وضعیت

گام ۳ از ۵ (+ نرخ زنده، ماشین‌حساب طلا و وام، سپر ضدتورم؛ فید نرخ: [`docs/rates-feed.md`](docs/rates-feed.md)) — جزئیات معماری، اسکیمای دیتابیس، موتور پیامک و قوانین تبلیغات در
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

فونت Vazirmatn تحت مجوز SIL OFL 1.1 — [`licenses/Vazirmatn-OFL.txt`](licenses/Vazirmatn-OFL.txt).
