/// رابط پرداخت درون‌برنامه‌ای (بخش ۹-۳). پیاده‌سازی‌های BazaarBilling
/// (Poolakey) و MyketBilling بعد از ساخت حساب فروشگاه‌ها اضافه می‌شوند.
/// اعتبارسنجی نهایی همیشه سمت سرور است.
library;

enum SubscriptionPlan { monthly, quarterly, yearly }

/// شناسه‌ی محصول در فروشگاه؛ باید با PRODUCT_DAYS سرور یکی باشد.
String productIdOf(SubscriptionPlan p) => switch (p) {
  SubscriptionPlan.monthly => 'premium_monthly',
  SubscriptionPlan.quarterly => 'premium_quarterly',
  SubscriptionPlan.yearly => 'premium_yearly',
};

class ProductInfo {
  const ProductInfo(this.plan, {this.price});

  final SubscriptionPlan plan;

  /// قیمت قالب‌بندی‌شده از فروشگاه؛ null یعنی هنوز معلوم نیست.
  final String? price;

  String get productId => productIdOf(plan);
}

class PurchaseResult {
  const PurchaseResult({
    required this.success,
    this.plan,
    this.purchaseToken,
    this.errorCode,
  });

  final bool success;
  final SubscriptionPlan? plan;

  /// برای `/purchase/verify` سرور.
  final String? purchaseToken;
  final String? errorCode;

  static const cancelled = PurchaseResult(
    success: false,
    errorCode: 'cancelled',
  );
  static const unavailable = PurchaseResult(
    success: false,
    errorCode: 'unavailable',
  );
}

abstract interface class BillingService {
  /// `bazaar` یا `myket` (برای سرور).
  String get storeId;

  Future<void> connect();

  Future<List<ProductInfo>> products();

  Future<PurchaseResult> purchase(SubscriptionPlan plan);

  /// خریدهای قبلی (بعد از نصب دوباره).
  Future<List<PurchaseResult>> restorePurchases();

  Future<void> disconnect();
}

/// پرداخت هنوز فعال نیست (release بدون SDK فروشگاه).
class UnavailableBillingService implements BillingService {
  const UnavailableBillingService(this.storeId);

  @override
  final String storeId;

  @override
  Future<void> connect() async {}

  @override
  Future<List<ProductInfo>> products() async => [
    for (final p in SubscriptionPlan.values) ProductInfo(p),
  ];

  @override
  Future<PurchaseResult> purchase(SubscriptionPlan plan) async =>
      PurchaseResult.unavailable;

  @override
  Future<List<PurchaseResult>> restorePurchases() async => const [];

  @override
  Future<void> disconnect() async {}
}

/// پیاده‌سازی جعلی: توکن‌های «test-…» که FakePurchaseVerifier سرور می‌پذیرد.
class FakeBillingService implements BillingService {
  FakeBillingService({this.storeId = 'bazaar', this.succeed = true});

  @override
  final String storeId;
  bool succeed;

  /// خریدهای «حساب فروشگاه» (بعد از نصب دوباره هم می‌مانند).
  final List<PurchaseResult> owned = [];

  @override
  Future<void> connect() async {}

  @override
  Future<List<ProductInfo>> products() async => [
    for (final p in SubscriptionPlan.values) ProductInfo(p),
  ];

  @override
  Future<PurchaseResult> purchase(SubscriptionPlan plan) async {
    if (!succeed) return PurchaseResult.cancelled;
    final r = PurchaseResult(
      success: true,
      plan: plan,
      purchaseToken: 'test-${plan.name}-${owned.length + 1}',
    );
    owned.add(r);
    return r;
  }

  @override
  Future<List<PurchaseResult>> restorePurchases() async =>
      List.unmodifiable(owned);

  @override
  Future<void> disconnect() async {}
}
