import 'package:calorie_lens/core/ads/ad_service.dart';
import 'package:calorie_lens/core/billing/billing_service.dart';
import 'package:calorie_lens/core/recognition/food_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FakeAdService: پاداش فقط با دیدن کامل', () async {
    final skipped = await FakeAdService(rewardResult: RewardResult.skipped)
        .showRewarded(AdPlacement.rewardedScan);
    expect(skipped.rewarded, isFalse);
    final done = await FakeAdService().showRewarded(AdPlacement.rewardedScan);
    expect(done.rewarded, isTrue);
    expect(done.rewardToken, isNotEmpty);
  });

  test('FakeBillingService خرید و بازیابی', () async {
    final b = FakeBillingService();
    final r = await b.purchase(SubscriptionPlan.yearly);
    expect(r.success, isTrue);
    expect(r.purchaseToken, startsWith('test-'));
    expect((await b.restorePurchases()).single.plan, SubscriptionPlan.yearly);
    expect(productIdOf(SubscriptionPlan.yearly), 'premium_yearly');
  });

  test('RecognitionResult.fromJson طبق اسکیمای بخش ۸-۲', () {
    final r = RecognitionResult.fromJson({
      'items': [
        {
          'food_id': null,
          'name_fa': 'گوجه کبابی',
          'quantity': 1,
          'unit': 'piece',
          'confidence': 0.7,
        },
      ],
      'is_food': true,
      'notes_fa': 'بخشی از بشقاب خارج از کادر است',
    });
    expect(r.isFood, isTrue);
    expect(r.items.single.foodId, isNull);
    expect(r.items.single.quantity, 1.0);
  });

  test('FakeFoodRecognizer پاسخ پیش‌فرض دارد', () async {
    final r = await FakeFoodRecognizer().recognize(const []);
    expect(r.items, isNotEmpty);
  });

  test('OnDeviceRecognizer هنوز پیاده نشده', () {
    expect(
      () => OnDeviceRecognizer().recognize(const []),
      throwsUnimplementedError,
    );
  });
}
