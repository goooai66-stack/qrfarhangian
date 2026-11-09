import 'package:calorie_lens/core/ads/ad_service.dart';
import 'package:calorie_lens/core/billing/billing_service.dart';
import 'package:calorie_lens/core/recognition/food_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FakeAdService نتیجه‌ی تنظیم‌شده را برمی‌گرداند', () async {
    final ads = FakeAdService(rewardResult: RewardResult.skipped);
    expect(
      await ads.showRewarded(AdPlacement.rewardedScan),
      RewardResult.skipped,
    );
    expect(ads.rewardedShown, 1);
  });

  test('FakeBillingService خرید و بازیابی', () async {
    final b = FakeBillingService();
    final r = await b.purchase(SubscriptionPlan.yearly);
    expect(r.success, isTrue);
    expect((await b.restorePurchases()).single.plan, SubscriptionPlan.yearly);
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
