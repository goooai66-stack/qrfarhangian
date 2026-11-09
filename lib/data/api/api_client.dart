import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../db/app_database.dart';

/// نوع خطای سرور واسط؛ اپ بر اساس آن پیام فارسی نشان می‌دهد.
enum ApiErrorKind {
  /// اینترنت نیست یا سرور در دسترس نیست.
  offline,

  /// پاسخ به‌موقع نیامد.
  timeout,

  /// سهمیه‌ی امروز تمام شد.
  quotaExceeded,

  /// درخواست زیاد در زمان کوتاه.
  rateLimited,

  /// سرور یا مدل شلوغ است.
  busy,

  /// عکس قابل قبول نیست (حجم/قالب).
  badImage,

  /// سقف ویدیوی جایزه‌دار امروز پر شد.
  rewardLimit,

  /// خرید تأیید نشد (توکن نامعتبر یا منقضی).
  invalidPurchase,

  /// اعتبارسنجی خرید فعلاً در دسترس نیست.
  verificationUnavailable,

  /// سایر خطاها.
  server,
}

class ApiException implements Exception {
  ApiException(this.kind, [this.detail]);

  final ApiErrorKind kind;
  final String? detail;

  @override
  String toString() => 'ApiException($kind, $detail)';
}

/// کلاینت سرور واسط (بخش ۱۰-۴). کلید هوش مصنوعی هرگز در اپ نیست؛
/// اپ فقط یک توکن ناشناس دستگاه دارد.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.db,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 25),
  }) : _http = httpClient ?? http.Client();

  static const _tokenKey = 'api_token';
  static const _deviceKey = 'device_id';

  final String baseUrl;
  final AppDatabase db;
  final http.Client _http;
  final Duration timeout;
  String? _token;

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  /// شناسه‌ی تصادفی دستگاه (بدون داده‌ی شخصی)، یک‌بار ساخته و نگه‌داری می‌شود.
  Future<String> _deviceId() async {
    final existing = await db.getSetting(_deviceKey);
    if (existing != null) return existing;
    final r = Random.secure();
    final id = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
    await db.setSetting(_deviceKey, id);
    return id;
  }

  Future<String> _ensureToken({bool force = false}) async {
    if (!force) {
      _token ??= await db.getSetting(_tokenKey);
      if (_token != null) return _token!;
    }
    final deviceId = await _deviceId();
    final res = await _send(
      () => _http.post(
        _uri('/auth/device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_id': deviceId}),
      ),
    );
    final token = (_decode(res)['token'] as String?);
    if (token == null) throw ApiException(ApiErrorKind.server, 'no token');
    _token = token;
    await db.setSetting(_tokenKey, token);
    return token;
  }

  /// سهمیه‌ی امروز: {used, limit, remaining}.
  Future<Map<String, dynamic>> quota() => _authed(
    (t) => _http.get(_uri('/quota'), headers: {'Authorization': 'Bearer $t'}),
  );

  /// ویدیوی جایزه‌دار کامل دیده شد ← ۱ اسکن بیشتر؛ سهمیه‌ی جدید.
  Future<Map<String, dynamic>> rewardScan(String rewardToken) => _authed(
    (t) => _http.post(
      _uri('/quota/reward'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reward_token': rewardToken}),
    ),
  );

  /// اعتبارسنجی خرید سمت سرور ← فعال‌سازی ویژه؛ سهمیه‌ی جدید.
  Future<Map<String, dynamic>> verifyPurchase({
    required String store,
    required String productId,
    required String purchaseToken,
  }) => _authed(
    (t) => _http.post(
      _uri('/purchase/verify'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'store': store,
        'product_id': productId,
        'purchase_token': purchaseToken,
      }),
    ),
  );

  /// عکس فشرده ← JSON نتیجه (بخش ۸-۲).
  Future<Map<String, dynamic>> scan(List<int> jpeg) => _authed((t) async {
    final req = http.MultipartRequest('POST', _uri('/scan'))
      ..headers['Authorization'] = 'Bearer $t'
      ..files.add(
        http.MultipartFile.fromBytes('image', jpeg, filename: 'meal.jpg'),
      );
    return http.Response.fromStream(await _http.send(req));
  });

  /// درخواست با توکن؛ اگر توکن باطل شده بود، یک‌بار دوباره ثبت می‌کند.
  Future<Map<String, dynamic>> _authed(
    Future<http.Response> Function(String token) call,
  ) async {
    final token = await _ensureToken();
    final res = await _send(() => call(token), allow401: true);
    if (res.statusCode == 401) {
      final fresh = await _ensureToken(force: true);
      return _decode(await _send(() => call(fresh)));
    }
    return _decode(res);
  }

  Future<http.Response> _send(
    Future<http.Response> Function() call, {
    bool allow401 = false,
  }) async {
    final http.Response res;
    try {
      res = await call().timeout(timeout);
    } on TimeoutException {
      throw ApiException(ApiErrorKind.timeout);
    } on SocketException catch (e) {
      throw ApiException(ApiErrorKind.offline, e.message);
    } on http.ClientException catch (e) {
      throw ApiException(ApiErrorKind.offline, e.message);
    } on HandshakeException catch (e) {
      throw ApiException(ApiErrorKind.offline, e.message);
    }
    if (res.statusCode == 401 && allow401) return res;
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    throw ApiException(_kindFor(res), 'HTTP ${res.statusCode}');
  }

  static ApiErrorKind _kindFor(http.Response res) {
    String? code;
    try {
      code =
          ((jsonDecode(utf8.decode(res.bodyBytes)) as Map)['error']
                  as Map?)?['code']
              as String?;
    } catch (_) {}
    return switch ((res.statusCode, code)) {
      (429, 'quota_exceeded') => ApiErrorKind.quotaExceeded,
      (429, 'reward_limit') => ApiErrorKind.rewardLimit,
      (402, _) => ApiErrorKind.invalidPurchase,
      (503, 'verification_unavailable') => ApiErrorKind.verificationUnavailable,
      (429, _) => ApiErrorKind.rateLimited,
      (413 || 415, _) => ApiErrorKind.badImage,
      (504, _) => ApiErrorKind.timeout,
      (503 || 502, _) => ApiErrorKind.busy,
      _ => ApiErrorKind.server,
    };
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return (jsonDecode(utf8.decode(res.bodyBytes)) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      throw ApiException(ApiErrorKind.server, 'invalid json');
    }
  }
}
