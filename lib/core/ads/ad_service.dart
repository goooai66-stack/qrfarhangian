/// رابط تبلیغات (بخش ۹-۲). پیاده‌سازی واقعی تپسل‌پلاس بعد از ساخت حساب و
/// گرفتن کلید اضافه می‌شود (TapsellAdService)؛ قوانین تکرار در [AdPolicy].
library;

import 'package:flutter/widgets.dart';

enum AdPlacement {
  rewardedScan,
  interstitialAfterLog,
  nativeProgress,
  bannerSearch,
}

/// نتیجه‌ی ویدیوی جایزه‌دار.
enum RewardResult { completed, skipped, unavailable, error }

class RewardOutcome {
  const RewardOutcome(this.result, {this.rewardToken});

  final RewardResult result;

  /// شناسه‌ای که برای تأیید پاداش به سرور فرستاده می‌شود.
  final String? rewardToken;

  bool get rewarded => result == RewardResult.completed && rewardToken != null;
}

abstract interface class AdService {
  Future<void> initialize();

  /// ویدیوی جایزه‌دار؛ پاداش فقط اگر کاربر تا آخر ببیند.
  Future<RewardOutcome> showRewarded(AdPlacement placement);

  /// تمام‌صفحه؛ true یعنی نمایش داده شد.
  Future<bool> showInterstitial(AdPlacement placement);

  /// بنر یا نیتیو؛ null یعنی چیزی برای نمایش نیست.
  Widget? inline(AdPlacement placement);
}

/// بدون شبکه‌ی تبلیغاتی (نسخه‌ی release تا وقتی کلید تپسل تنظیم نشده).
class NoAdService implements AdService {
  const NoAdService();

  @override
  Future<void> initialize() async {}

  @override
  Future<RewardOutcome> showRewarded(AdPlacement placement) async =>
      const RewardOutcome(RewardResult.unavailable);

  @override
  Future<bool> showInterstitial(AdPlacement placement) async => false;

  @override
  Widget? inline(AdPlacement placement) => null;
}

/// پیاده‌سازی جعلی برای توسعه و تست.
class FakeAdService implements AdService {
  FakeAdService({
    this.rewardResult = RewardResult.completed,
    this.placeholders = false,
  });

  RewardResult rewardResult;

  /// در حالت توسعه، جای بنر/نیتیو یک قاب نمونه نشان داده می‌شود.
  final bool placeholders;
  int rewardedShown = 0;
  int interstitialShown = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<RewardOutcome> showRewarded(AdPlacement placement) async {
    rewardedShown++;
    return RewardOutcome(
      rewardResult,
      rewardToken: rewardResult == RewardResult.completed
          ? 'fake-reward-$rewardedShown'
          : null,
    );
  }

  @override
  Future<bool> showInterstitial(AdPlacement placement) async {
    interstitialShown++;
    return true;
  }

  @override
  Widget? inline(AdPlacement placement) => placeholders
      ? Container(
          key: ValueKey('fake-ad-${placement.name}'),
          height: placement == AdPlacement.bannerSearch ? 50 : 90,
          alignment: Alignment.center,
          color: const Color(0x14000000),
          child: Text('AD · ${placement.name}'),
        )
      : null;
}
