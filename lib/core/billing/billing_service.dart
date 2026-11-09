/// رابط پرداخت درون‌برنامه‌ای. پیاده‌سازی‌های BazaarBilling (Poolakey) و
/// MyketBilling در مرحله‌ی ۵، بر اساس Flavor انتخاب می‌شوند.
/// اعتبارسنجی نهایی خرید همیشه سمت سرور است (بخش ۹-۳).
library;

enum SubscriptionPlan { monthly, quarterly, yearly }

class PurchaseResult {
  const PurchaseResult({
    required this.success,
    this.plan,
    this.purchaseToken,
    this.errorCode,
  });

  final bool success;
  final SubscriptionPlan? plan;

  /// توکنی که برای `/purchase/verify` به سرور فرستاده می‌شود.
  final String? purchaseToken;
  final String? errorCode;
}

abstract interface class BillingService {
  /// نام فروشگاه، مثل `bazaar` یا `myket`.
  String get storeId;

  Future<void> connect();

  Future<PurchaseResult> purchase(SubscriptionPlan plan);

  /// بازیابی خریدهای قبلی (بعد از نصب دوباره).
  Future<List<PurchaseResult>> restorePurchases();

  Future<void> disconnect();
}

/// پیاده‌سازی جعلی برای توسعه و تست.
class FakeBillingService implements BillingService {
  FakeBillingService({this.storeId = 'fake', this.succeed = true});

  @override
  final String storeId;
  bool succeed;
  final List<PurchaseResult> _purchases = [];

  @override
  Future<void> connect() async {}

  @override
  Future<PurchaseResult> purchase(SubscriptionPlan plan) async {
    final r = succeed
        ? PurchaseResult(
            success: true,
            plan: plan,
            purchaseToken: 'fake-token-${plan.name}',
          )
        : const PurchaseResult(success: false, errorCode: 'fake_failure');
    if (r.success) _purchases.add(r);
    return r;
  }

  @override
  Future<List<PurchaseResult>> restorePurchases() async =>
      List.unmodifiable(_purchases);

  @override
  Future<void> disconnect() async {}
}
