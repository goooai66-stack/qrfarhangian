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

### OpenRouter

```env
VISION_PROVIDER=openai_compatible
OPENAI_COMPAT_BASE_URL=https://openrouter.ai/api/v1
OPENAI_COMPAT_API_KEY=...            # فقط روی سرور
OPENAI_COMPAT_MODEL=...              # مدلی با ورودی تصویر از openrouter.ai/models
OPENAI_COMPAT_REFERER=https://...    # اختیاری
OPENAI_COMPAT_TITLE=CalorieLens      # اختیاری
PRICE_INPUT_PER_MTOK=...             # از صفحه‌ی همان مدل
PRICE_OUTPUT_PER_MTOK=...
```

اگر مدلی `json_schema` را نپذیرد، آداپتر خودکار به `json_object` برمی‌گردد (اسکیما در پرامپت)؛
خروجی در هر حال سخت‌گیرانه بررسی می‌شود.

### انتخاب مدل: مقایسه روی عکس واقعی (بخش ۸-۵)

۱۰ تا ۵۰ عکس واقعی غذای ایرانی را در یک پوشه بگذارید و چند مدل را مقایسه کنید:

```bash
pip install -r requirements-dev.txt
python -m tools.eval_photos --photos ./photos \
    --models "model-a,model-b,model-c" \
    --prices "model-a=0.10:0.40,model-b=1.00:4.00,model-c=3:15" --out ./eval
```

خروجی `eval/results.md`: جدول خلاصه (موفق، JSON نامعتبر، آیتم تطبیق‌نخورده، زمان میانگین و p90،
درصد زیر ۸ ثانیه، هزینه‌ی هر اسکن) و جدول جزئیات با ستون «درست؟» برای بررسی چشمی.
ارزان‌ترین مدلی را انتخاب کنید که دقتش قابل قبول است. سهمیه و دیتابیس سرور درگیر نمی‌شوند.

## API

| متد | مسیر | کار |
|---|---|---|
| POST | `/auth/device` | `{device_id}` ← `{token}` (توکن ناشناس دستگاه) |
| GET | `/quota` | `{used, limit, remaining, day}` |
| POST | `/scan` | `multipart: image` ← `{scan_id, is_food, notes_fa, items[], quota}` |
| POST | `/quota/reward` | `{reward_token}` ← ویدیوی کامل = ۱ اسکن (حداکثر ۵ در روز) |
| POST | `/purchase/verify` | `{store, product_id, purchase_token}` ← ویژه؛ بازیابی بعد از نصب دوباره هم همین |
| GET | `/admin/stats?days=30` | هدر `X-Admin-Token`؛ هزینه‌ی روزانه و هزینه‌ی هر دستگاه فعال |
| GET | `/health` | وضعیت |

کدهای خطا (`{"error": {"code": ...}}`): `quota_exceeded` و `rate_limited` (۴۲۹)،
`provider_busy` (۵۰۳)، `provider_timeout` (۵۰۴)، `provider_error` / `provider_refused` /
`invalid_model_output` (۵۰۲)، `image_too_large` (۴۱۳)، `unsupported_image` (۴۱۵)، `unauthorized` (۴۰۱).

## محدودیت‌های فعلی (برای مراحل بعد)

- SQLite و محدودیت نرخ در حافظه ← برای چند نمونه‌ی سرور، PostgreSQL و Redis.
- ثبت دستگاه ناشناس است؛ کسی می‌تواند با ساختن دستگاه‌های زیاد سهمیه‌ی بیشتری بگیرد (محدودیت ۱۰ ثبت در ساعت برای هر IP). راه‌حل کامل: ورود با موبایل (P1) یا تأیید یکپارچگی دستگاه.
- اعتبارسنجی واقعی خرید (API توسعه‌دهنده‌ی کافه‌بازار و مایکت) و تأیید پاداش تپسل هنوز وصل نیست:
  `app/billing/verifiers.py` (`NotConfiguredPurchaseVerifier`، `TrustingRewardVerifier`). در تولید
  `PURCHASE_VERIFIER=fake` نگذارید.
- `/voice` و `/feedback/scan` (مرحله‌ی ۶) هنوز نیستند.
