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

  /// سهمیه‌ی ثبت صوتی/متنی امروز تمام شد.
  voiceQuotaExceeded,

  /// کد دعوت پیدا نشد / کد خود کاربر / قبلاً کدی وارد شده.
  invalidCode,
  ownCode,
  alreadyRedeemed,

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

  /// آدرس وارد‌شده را مرتب می‌کند؛ null یعنی نامعتبر.
  /// فقط https پذیرفته می‌شود (http فقط با [allowHttp] برای توسعه).
  static String? normalizeUrl(String input, {bool allowHttp = false}) {
    var v = input.trim();
    if (v.isEmpty) return null;
    if (!v.contains('://')) v = 'https://$v';
    final u = Uri.tryParse(v);
    if (u == null || u.hasQuery || u.hasFragment || u.userInfo.isNotEmpty) {
      return null;
    }
    if (!RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$')
        .hasMatch(u.host)) {
      return null;
    }
    if (u.scheme != 'https' && !(allowHttp && u.scheme == 'http')) return null;
    final port = u.hasPort ? ':${u.port}' : '';
    final path = u.path.replaceAll(RegExp(r'/+$'), '');
    return '${u.scheme}://${u.host.toLowerCase()}$port$path';
  }

  /// آیا این آدرس واقعاً سرور کالری‌لنز است؟ (`GET /health`)
  static Future<bool> probe(
    String baseUrl, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final c = client ?? http.Client();
    try {
      final res = await c.get(Uri.parse('$baseUrl/health')).timeout(timeout);
      if (res.statusCode != 200) return false;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      return body is Map && body['ok'] == true && body.containsKey('foods');
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }

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
      if (_token != null && _token!.isNotEmpty) return _token!;
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

  Map<String, String> _json(String t) => {
    'Authorization': 'Bearer $t',
    'Content-Type': 'application/json',
  };

  /// جمله‌ی غذا (از صدا یا تایپ) ← همان JSON آیتم‌ها + meal (بخش ۸-۴).
  Future<Map<String, dynamic>> voice(String text) => _authed(
    (t) => _http.post(
      _uri('/voice'),
      headers: _json(t),
      body: jsonEncode({'text': text}),
    ),
  );

  Future<Map<String, dynamic>> invite() => _authed(
    (t) => _http.get(_uri('/invite'), headers: {'Authorization': 'Bearer $t'}),
  );

  Future<Map<String, dynamic>> redeemInvite(String code) => _authed(
    (t) => _http.post(
      _uri('/invite/redeem'),
      headers: _json(t),
      body: jsonEncode({'code': code}),
    ),
  );

  Future<Map<String, dynamic>> feedbackScan(Map<String, dynamic> body) =>
      _authed(
        (t) => _http.post(
          _uri('/feedback/scan'),
          headers: _json(t),
          body: jsonEncode(body),
        ),
      );

  Future<Map<String, dynamic>> sendEvents(List<Map<String, Object>> events) =>
      _authed(
        (t) => _http.post(
          _uri('/events'),
          headers: _json(t),
          body: jsonEncode({'events': events}),
        ),
      );

  /// «حذف همه‌ی داده‌ها»: داده‌های این دستگاه روی سرور.
  Future<void> deleteDevice() async {
    await _authed(
      (t) => _http.delete(
        _uri('/device'),
        headers: {'Authorization': 'Bearer $t'},
      ),
    );
    _token = null;
    await db.setSetting(_tokenKey, '');
  }

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
    // هنوز آدرس سروری وارد نشده: مثل بی‌اینترنتی رفتار می‌کنیم (صف آفلاین).
    if (baseUrl.isEmpty) throw ApiException(ApiErrorKind.offline, 'no server');
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
      (429, 'voice_quota_exceeded') => ApiErrorKind.voiceQuotaExceeded,
      (404, 'invalid_code') => ApiErrorKind.invalidCode,
      (400, 'own_code') => ApiErrorKind.ownCode,
      (409, 'already_redeemed') => ApiErrorKind.alreadyRedeemed,
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
