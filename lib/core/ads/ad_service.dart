/// رابط تبلیغات. پیاده‌سازی واقعی (TapsellAdService) در مرحله‌ی ۵.
///
/// قوانین بخش ۹-۲ (سقف تکرار تمام‌صفحه، عدم نمایش در ۲ دقیقه‌ی اول، …)
/// در مرحله‌ی ۵ داخل پیاده‌سازی/لایه‌ی سیاست اعمال می‌شوند.
library;

enum AdPlacement {
  rewardedScan,
  interstitialAfterLog,
  nativeProgress,
  bannerSearch,
}

/// نتیجه‌ی ویدیوی جایزه‌دار.
enum RewardResult { completed, skipped, unavailable, error }

abstract interface class AdService {
  Future<void> initialize();

  /// برای کاربر ویژه همیشه false.
  bool get adsEnabled;

  /// ویدیوی جایزه‌دار؛ جایزه فقط با [RewardResult.completed].
  Future<RewardResult> showRewarded(AdPlacement placement);

  /// تمام‌صفحه؛ true یعنی نمایش داده شد.
  Future<bool> showInterstitial(AdPlacement placement);
}

/// پیاده‌سازی جعلی برای توسعه و تست: هیچ تبلیغی نشان نمی‌دهد.
class FakeAdService implements AdService {
  FakeAdService({this.rewardResult = RewardResult.completed});

  RewardResult rewardResult;
  int rewardedShown = 0;
  int interstitialShown = 0;

  @override
  bool get adsEnabled => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<RewardResult> showRewarded(AdPlacement placement) async {
    rewardedShown++;
    return rewardResult;
  }

  @override
  Future<bool> showInterstitial(AdPlacement placement) async {
    interstitialShown++;
    return true;
  }
}
