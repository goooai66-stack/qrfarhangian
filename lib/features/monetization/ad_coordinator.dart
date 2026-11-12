import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ads/ad_policy.dart';
import '../../core/ads/ad_service.dart';
import '../../core/utils/jalali_date.dart';
import '../../data/api/api_client.dart';

/// نتیجه‌ی «دیدن ویدیو = ۱ اسکن».
enum RewardFlowResult {
  /// پاداش ثبت شد؛ دوباره اسکن کن.
  granted,

  /// ویدیو کامل دیده نشد؛ پاداشی نیست.
  notCompleted,

  /// ویدیویی برای نمایش نیست.
  unavailable,

  /// سقف ویدیوی امروز پر است.
  limitReached,

  /// خطای شبکه یا سرور.
  failed,
}

/// همه‌ی تبلیغ‌ها از اینجا می‌گذرند تا قوانین بخش ۹-۲ و وضعیت ویژه
/// همیشه اعمال شوند.
class AdCoordinator {
  AdCoordinator(this._ref)
    : _policy = AdPolicy(sessionStart: _ref.read(clockProvider)());

  final Ref _ref;
  final AdPolicy _policy;
  bool _loaded = false;

  static const _dayKey = 'ads_day';
  static const _countKey = 'ads_count';

  /// کاربر ویژه یا انتشار رایگان (درآمدزایی خاموش) ← بدون تبلیغ.
  bool get _premium =>
      _ref.read(isPremiumProvider) || !_ref.read(monetizationEnabledProvider);
  AdService get _ads => _ref.read(adServiceProvider);
  DateTime _now() => _ref.read(clockProvider)();

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final db = _ref.read(databaseProvider);
    _policy.countedDay = await db.getSetting(_dayKey);
    _policy.shownToday =
        int.tryParse(await db.getSetting(_countKey) ?? '') ?? 0;
  }

  /// بعد از ذخیره‌ی وعده: تمام‌صفحه، فقط اگر قوانین اجازه دهند.
  Future<bool> afterLogSaved() async {
    await _load();
    final now = _now();
    final today = dayKey(now);
    if (!_policy.canShowInterstitial(
      now: now,
      today: today,
      premium: _premium,
    )) {
      return false;
    }
    final shown = await _ads.showInterstitial(AdPlacement.interstitialAfterLog);
    if (shown) {
      _policy.recordInterstitial(now: now, today: today);
      final db = _ref.read(databaseProvider);
      await db.setSetting(_dayKey, today);
      await db.setSetting(_countKey, '${_policy.shownToday}');
    }
    return shown;
  }

  /// فقط با انتخاب خود کاربر؛ پاداش فقط بعد از کامل دیدن و تأیید سرور.
  Future<RewardFlowResult> watchVideoForScan() async {
    if (_premium) return RewardFlowResult.unavailable;
    final outcome = await _ads.showRewarded(AdPlacement.rewardedScan);
    if (outcome.result == RewardResult.unavailable ||
        outcome.result == RewardResult.error) {
      return RewardFlowResult.unavailable;
    }
    if (!outcome.rewarded) return RewardFlowResult.notCompleted;
    try {
      final q = await _ref
          .read(monetizationApiProvider)
          .claimReward(outcome.rewardToken!);
      _ref.read(entitlementProvider.notifier).apply(q);
      return RewardFlowResult.granted;
    } on ApiException catch (e) {
      return e.kind == ApiErrorKind.rewardLimit
          ? RewardFlowResult.limitReached
          : RewardFlowResult.failed;
    } catch (_) {
      return RewardFlowResult.failed;
    }
  }

  /// بنر/نیتیو؛ برای کاربر ویژه هیچ.
  Widget? inline(AdPlacement placement) =>
      _premium ? null : _ads.inline(placement);
}

/// جای بنر یا تبلیغ نیتیو، با برچسب «تبلیغ».
class AdSlot extends ConsumerWidget {
  const AdSlot(this.placement, {super.key, this.label});

  final AdPlacement placement;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(isPremiumProvider);
    final ad = ref.watch(adCoordinatorProvider).inline(placement);
    if (ad == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, bottom: 2),
            child: Text(label!, style: const TextStyle(fontSize: 11)),
          ),
        ad,
      ],
    );
  }
}
