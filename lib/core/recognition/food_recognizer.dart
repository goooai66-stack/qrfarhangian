/// رابط تشخیص غذا از عکس (بخش ۸).
///
/// اصل کلیدی: تشخیص‌دهنده فقط «چه غذایی و چقدر» را برمی‌گرداند؛
/// کالری از پایگاه داده‌ی خودمان حساب می‌شود، نه از خروجی مدل.
/// پیاده‌سازی‌ها: CloudRecognizer (مرحله‌ی ۳)، OnDeviceRecognizer (P2، فعلاً خالی).
library;

import '../../data/api/api_client.dart';
import '../nutrition/nutrition_types.dart';

export '../../data/api/api_client.dart' show ApiErrorKind;

class RecognizedItem {
  const RecognizedItem({
    required this.foodId,
    required this.nameFa,
    required this.quantity,
    required this.unit,
    required this.confidence,
  });

  /// null یعنی غذا در پایگاه داده پیدا نشد.
  final String? foodId;
  final String nameFa;
  final double quantity;
  final String unit;

  /// ۰ تا ۱
  final double confidence;

  factory RecognizedItem.fromJson(Map<String, dynamic> j) => RecognizedItem(
    foodId: j['food_id'] as String?,
    nameFa: j['name_fa'] as String,
    quantity: (j['quantity'] as num).toDouble(),
    unit: j['unit'] as String,
    confidence: (j['confidence'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'food_id': foodId,
    'name_fa': nameFa,
    'quantity': quantity,
    'unit': unit,
    'confidence': confidence,
  };
}

class RecognitionResult {
  const RecognitionResult({
    required this.items,
    required this.isFood,
    this.notesFa,
    this.scanId,
    this.quotaRemaining,
    this.meal,
  });

  final List<RecognizedItem> items;
  final bool isFood;
  final String? notesFa;
  final String? scanId;

  /// اسکن‌های باقی‌مانده‌ی امروز (اگر سرور گفته باشد).
  final int? quotaRemaining;

  /// وعده‌ای که در جمله گفته شده (ثبت صوتی/متنی)؛ null یعنی گفته نشده.
  final MealType? meal;

  factory RecognitionResult.fromJson(Map<String, dynamic> j) =>
      RecognitionResult(
        items: [
          for (final e in (j['items'] as List? ?? const []))
            RecognizedItem.fromJson((e as Map).cast<String, dynamic>()),
        ],
        isFood: j['is_food'] as bool? ?? false,
        notesFa: j['notes_fa'] as String?,
        scanId: j['scan_id'] as String?,
        quotaRemaining: ((j['quota'] as Map?)?['remaining'] as num?)?.toInt(),
        meal: MealType.values.where((m) => m.name == j['meal']).firstOrNull,
      );

  Map<String, dynamic> toJson() => {
    'items': [for (final i in items) i.toJson()],
    'is_food': isFood,
    'notes_fa': notesFa,
    'scan_id': scanId,
    'meal': meal?.name,
  };
}

/// خطای تشخیص؛ [kind] همان دسته‌بندی خطای سرور واسط است.
class RecognitionException implements Exception {
  RecognitionException(this.kind, [this.detail]);

  final ApiErrorKind kind;
  final String? detail;

  @override
  String toString() => 'RecognitionException($kind, $detail)';
}

abstract interface class FoodRecognizer {
  /// [imageBytes]: عکس فشرده‌شده (بخش ۵-۲).
  Future<RecognitionResult> recognize(List<int> imageBytes);
}

/// پیاده‌سازی جعلی با پاسخ ثابت؛ برای توسعه‌ی UI و تست.
/// food_idها نمونه‌اند و مقدار تغذیه‌ای ندارند.
class FakeFoodRecognizer implements FoodRecognizer {
  FakeFoodRecognizer({
    RecognitionResult? result,
    this.delay = Duration.zero,
    this.error,
  }) : result =
           result ??
           const RecognitionResult(
             isFood: true,
             items: [
               RecognizedItem(
                 foodId: 'chelo',
                 nameFa: 'چلو',
                 quantity: 1.5,
                 unit: 'kafgir',
                 confidence: 0.86,
               ),
               RecognizedItem(
                 foodId: 'kabab_koobideh',
                 nameFa: 'کباب کوبیده',
                 quantity: 2,
                 unit: 'piece',
                 confidence: 0.91,
               ),
             ],
           );

  RecognitionResult result;
  final Duration delay;

  /// اگر تنظیم شود، به‌جای نتیجه این خطا پرتاب می‌شود.
  RecognitionException? error;
  int calls = 0;

  @override
  Future<RecognitionResult> recognize(List<int> imageBytes) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (error != null) throw error!;
    return result;
  }
}

/// تشخیص ابری از طریق سرور واسط خودمان (بخش ۸-۱).
class CloudRecognizer implements FoodRecognizer {
  CloudRecognizer(this._api);

  final ApiClient _api;

  @override
  Future<RecognitionResult> recognize(List<int> imageBytes) async {
    try {
      return RecognitionResult.fromJson(await _api.scan(imageBytes));
    } on ApiException catch (e) {
      throw RecognitionException(e.kind, e.detail);
    } on TypeError catch (e) {
      throw RecognitionException(ApiErrorKind.server, '$e');
    }
  }
}

/// جای خالی برای مدل روی گوشی (بخش ۸-۶، P2).
class OnDeviceRecognizer implements FoodRecognizer {
  @override
  Future<RecognitionResult> recognize(List<int> imageBytes) =>
      throw UnimplementedError('OnDeviceRecognizer در P2 پیاده می‌شود.');
}
