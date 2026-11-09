import '../api/api_client.dart';
import '../db/app_database.dart';

/// وضعیت سهمیه و اشتراک از دید سرور.
class QuotaStatus {
  const QuotaStatus({
    required this.premium,
    this.premiumUntil,
    this.remaining,
    this.limit,
    this.rewardsLeft = 0,
  });

  final bool premium;
  final DateTime? premiumUntil;
  final int? remaining;
  final int? limit;
  final int rewardsLeft;

  static const free = QuotaStatus(premium: false);

  factory QuotaStatus.fromJson(Map<String, dynamic> j) => QuotaStatus(
    premium: j['premium'] as bool? ?? false,
    premiumUntil: j['premium_until'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (j['premium_until'] as num).toInt() * 1000,
          ),
    remaining: (j['remaining'] as num?)?.toInt(),
    limit: (j['limit'] as num?)?.toInt(),
    rewardsLeft: (j['rewards_left'] as num?)?.toInt() ?? 0,
  );
}

/// عملیات درآمدی سرور؛ در تست با نسخه‌ی جعلی جایگزین می‌شود.
abstract interface class MonetizationApi {
  Future<QuotaStatus> quota();
  Future<QuotaStatus> claimReward(String rewardToken);
  Future<QuotaStatus> verifyPurchase({
    required String store,
    required String productId,
    required String purchaseToken,
  });
}

class ServerMonetizationApi implements MonetizationApi {
  ServerMonetizationApi(this._api);
  final ApiClient _api;

  @override
  Future<QuotaStatus> quota() async => QuotaStatus.fromJson(await _api.quota());

  @override
  Future<QuotaStatus> claimReward(String rewardToken) async =>
      QuotaStatus.fromJson(await _api.rewardScan(rewardToken));

  @override
  Future<QuotaStatus> verifyPurchase({
    required String store,
    required String productId,
    required String purchaseToken,
  }) async => QuotaStatus.fromJson(
    await _api.verifyPurchase(
      store: store,
      productId: productId,
      purchaseToken: purchaseToken,
    ),
  );
}

/// کش محلی وضعیت ویژه (برای حالت آفلاین و شروع سریع؛ منبع اصلی سرور است).
class PremiumCache {
  PremiumCache(this._db);
  final AppDatabase _db;
  static const _key = 'premium_until';

  Future<DateTime?> read() async {
    final v = await _db.getSetting(_key);
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<void> write(DateTime? until) =>
      _db.setSetting(_key, until?.toIso8601String() ?? '');
}

/// شبیه‌ساز سرور برای توسعه و تست: ۳ اسکن رایگان، ۵ ویدیو در روز،
/// توکن‌های «test-…» معتبر. همان قوانین server/app/main.py.
class FakeMonetizationApi implements MonetizationApi {
  FakeMonetizationApi({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  int used = 0;
  int rewards = 0;
  DateTime? premiumUntil;
  final purchaseTokens = <String>{};

  static const _free = 3, _rewardsPerDay = 5, _premiumLimit = 30;

  bool get _premium => premiumUntil != null && premiumUntil!.isAfter(_clock());

  QuotaStatus get _status {
    final limit = _premium ? _premiumLimit : _free + rewards;
    return QuotaStatus(
      premium: _premium,
      premiumUntil: _premium ? premiumUntil : null,
      remaining: (limit - used).clamp(0, limit),
      limit: limit,
      rewardsLeft: _premium ? 0 : _rewardsPerDay - rewards,
    );
  }

  @override
  Future<QuotaStatus> quota() async => _status;

  @override
  Future<QuotaStatus> claimReward(String rewardToken) async {
    if (rewards >= _rewardsPerDay) {
      throw ApiException(ApiErrorKind.rewardLimit);
    }
    rewards++;
    return _status;
  }

  @override
  Future<QuotaStatus> verifyPurchase({
    required String store,
    required String productId,
    required String purchaseToken,
  }) async {
    final days = const {
      'premium_monthly': 30,
      'premium_quarterly': 90,
      'premium_yearly': 365,
    }[productId];
    if (days == null || !purchaseToken.startsWith('test-')) {
      throw ApiException(ApiErrorKind.invalidPurchase);
    }
    purchaseTokens.add(purchaseToken);
    premiumUntil = _clock().add(Duration(days: days));
    return _status;
  }
}
