/// تنظیمات زمان ساخت (`--dart-define`). کلید هوش مصنوعی اینجا نیست و نباید باشد؛
/// اپ فقط آدرس سرور واسط خودمان را می‌داند.
abstract final class AppConfig {
  /// نسخه‌ی اپ؛ باید با `version` در pubspec.yaml یکی باشد (تست بررسی می‌کند).
  static const version = '1.0.0';

  /// آدرس سرور واسط، ثابت‌شده هنگام ساخت:
  /// `--dart-define=API_BASE_URL=https://api.example.com`
  /// خالی ← آدرس داخل اپ (درباره ← آدرس سرور) وارد می‌شود.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// آدرس هنگام ساخت داده نشده؛ کاربر باید در اپ واردش کند.
  static const serverConfigurable = apiBaseUrl == '';

  /// میزبان رایانه از دید شبیه‌ساز اندروید (فقط توسعه).
  static const emulatorServer = 'http://10.0.2.2:8000';

  /// `--dart-define=FAKE_SCAN=true` ← تشخیص جعلی بدون سرور (توسعه‌ی UI).
  static const fakeScan = bool.fromEnvironment('FAKE_SCAN');

  /// درآمدزایی (اشتراک، تبلیغ، دعوت). پیش‌فرض خاموش: انتشار اول رایگان است.
  /// برای روشن کردن: `--dart-define=MONETIZATION=true`
  static const monetization = bool.fromEnvironment('MONETIZATION');

  /// کلید تپسل‌پلاس (بعد از ساخت حساب). خالی ← بدون تبلیغ در release
  /// و تبلیغ نمونه در debug.
  static const tapsellKey = String.fromEnvironment('TAPSELL_KEY');
}
