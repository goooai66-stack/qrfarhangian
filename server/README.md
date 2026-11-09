# سرور واسط کالری‌لنز (مرحله‌ی ۳)

اپ عکس را به این سرور می‌فرستد؛ سرور سهمیه را بررسی می‌کند، عکس را به مدل بینایی
می‌دهد، خروجی را سخت‌گیرانه اعتبارسنجی می‌کند، با `food_id`های پایگاه غذا تطبیق
می‌دهد و **کالری را از `foods.json` خودمان** حساب می‌کند (نه از عدد مدل).

- کلید هوش مصنوعی فقط اینجا (متغیر محیطی) است؛ هرگز در اپ.
- عکس‌ها ذخیره نمی‌شوند؛ فقط نتیجه (برای کش) و لاگ هزینه.
- سهمیه سمت سرور: ۳ اسکن در روز (ریست نیمه‌شب تهران). «غذا نبود» و خطاها سهمیه را کم نمی‌کنند.

## اجرا (توسعه)

```bash
cd server
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
VISION_PROVIDER=fake uvicorn app.main:app --reload --port 8000
pytest -q
```

اپ روی شبیه‌ساز اندروید به `http://10.0.2.2:8000` وصل می‌شود (پیش‌فرض).

## اجرا با Docker (از ریشه‌ی پروژه)

```bash
cp server/.env.example server/.env   # و پر کنید
docker build -f server/Dockerfile -t calorielens-api .
docker run --env-file server/.env -p 8000:8000 -v cl-data:/data calorielens-api
```

در تولید حتماً پشت HTTPS (مثلاً Caddy یا Nginx) اجرا شود.

## ارائه‌دهنده‌ی مدل (قابل تعویض)

| `VISION_PROVIDER` | توضیح |
|---|---|
| `fake` | پاسخ ثابت؛ برای توسعه و تست |
| `anthropic` | Claude با SDK رسمی؛ `ANTHROPIC_API_KEY` و `ANTHROPIC_MODEL` |
| `openai_compatible` | هر سرویس سازگار با Chat Completions (OpenAI، Gemini، OpenRouter، درگاه‌های داخلی، مدل محلی) |

افزودن ارائه‌دهنده‌ی جدید: یک کلاس با متد `recognize` در `app/providers/` + یک خط در `build_provider`.

**پیش از انتخاب نهایی (بخش ۸-۵):** روی ۵۰ عکس غذای ایرانی مقایسه کنید (دقت، زمان، هزینه از `/admin/stats`).

## API

| متد | مسیر | کار |
|---|---|---|
| POST | `/auth/device` | `{device_id}` ← `{token}` (توکن ناشناس دستگاه) |
| GET | `/quota` | `{used, limit, remaining, day}` |
| POST | `/scan` | `multipart: image` ← `{scan_id, is_food, notes_fa, items[], quota}` |
| GET | `/admin/stats?days=30` | هدر `X-Admin-Token`؛ هزینه‌ی روزانه و هزینه‌ی هر دستگاه فعال |
| GET | `/health` | وضعیت |

کدهای خطا (`{"error": {"code": ...}}`): `quota_exceeded` و `rate_limited` (۴۲۹)،
`provider_busy` (۵۰۳)، `provider_timeout` (۵۰۴)، `provider_error` / `provider_refused` /
`invalid_model_output` (۵۰۲)، `image_too_large` (۴۱۳)، `unsupported_image` (۴۱۵)، `unauthorized` (۴۰۱).

## محدودیت‌های فعلی (برای مراحل بعد)

- SQLite و محدودیت نرخ در حافظه ← برای چند نمونه‌ی سرور، PostgreSQL و Redis.
- ثبت دستگاه ناشناس است؛ کسی می‌تواند با ساختن دستگاه‌های زیاد سهمیه‌ی بیشتری بگیرد (محدودیت ۱۰ ثبت در ساعت برای هر IP). راه‌حل کامل: ورود با موبایل (P1) یا تأیید یکپارچگی دستگاه.
- `/purchase/verify`، `/quota/reward` (مرحله‌ی ۵)، `/voice` و `/feedback/scan` (مرحله‌ی ۶) هنوز نیستند.
