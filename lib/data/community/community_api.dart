import '../api/api_client.dart';
import '../monetization/monetization.dart';

class InviteInfo {
  const InviteInfo({
    required this.code,
    required this.invited,
    this.redeemedCode,
    this.days = 7,
  });

  final String code;
  final int invited;

  /// کدی که خود کاربر قبلاً وارد کرده (یک‌بار مجاز است).
  final String? redeemedCode;
  final int days;
}

/// کد دعوت و «تشخیص اشتباه بود» (بخش ۴-۷، ۶).
abstract interface class CommunityApi {
  Future<InviteInfo> inviteInfo();
  Future<QuotaStatus> redeemInvite(String code);
  Future<void> sendScanFeedback({
    String? scanId,
    required List<Map<String, dynamic>> original,
    required List<Map<String, dynamic>> corrected,
    String? note,
  });
}

class ServerCommunityApi implements CommunityApi {
  ServerCommunityApi(this._api);
  final ApiClient _api;

  @override
  Future<InviteInfo> inviteInfo() async {
    final j = await _api.invite();
    return InviteInfo(
      code: j['code'] as String,
      invited: (j['invited'] as num?)?.toInt() ?? 0,
      redeemedCode: j['redeemed_code'] as String?,
      days: (j['days'] as num?)?.toInt() ?? 7,
    );
  }

  @override
  Future<QuotaStatus> redeemInvite(String code) async =>
      QuotaStatus.fromJson(await _api.redeemInvite(code));

  @override
  Future<void> sendScanFeedback({
    String? scanId,
    required List<Map<String, dynamic>> original,
    required List<Map<String, dynamic>> corrected,
    String? note,
  }) => _api.feedbackScan({
    'scan_id': scanId,
    'original': original,
    'corrected': corrected,
    'note': note,
  });
}

class FakeCommunityApi implements CommunityApi {
  FakeCommunityApi({this.code = 'ABC234', DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final String code;
  final DateTime Function() _clock;
  int invited = 0;
  String? redeemed;
  final feedback = <Map<String, dynamic>>[];

  @override
  Future<InviteInfo> inviteInfo() async =>
      InviteInfo(code: code, invited: invited, redeemedCode: redeemed);

  @override
  Future<QuotaStatus> redeemInvite(String c) async {
    final norm = c.trim().toUpperCase();
    if (norm == code) throw ApiException(ApiErrorKind.ownCode);
    if (redeemed != null) throw ApiException(ApiErrorKind.alreadyRedeemed);
    if (norm.length != 6) throw ApiException(ApiErrorKind.invalidCode);
    redeemed = norm;
    final until = _clock().add(const Duration(days: 7));
    return QuotaStatus(premium: true, premiumUntil: until);
  }

  @override
  Future<void> sendScanFeedback({
    String? scanId,
    required List<Map<String, dynamic>> original,
    required List<Map<String, dynamic>> corrected,
    String? note,
  }) async => feedback.add({
    'scan_id': scanId,
    'original': original,
    'corrected': corrected,
    'note': note,
  });
}
