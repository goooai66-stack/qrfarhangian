/// رابط تشخیص غذا از عکس (بخش ۸).
///
/// اصل کلیدی: تشخیص‌دهنده فقط «چه غذایی و چقدر» را برمی‌گرداند؛
/// کالری از پایگاه داده‌ی خودمان حساب می‌شود، نه از خروجی مدل.
/// پیاده‌سازی‌ها: CloudRecognizer (مرحله‌ی ۳)، OnDeviceRecognizer (P2، فعلاً خالی).
library;

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
}

class RecognitionResult {
  const RecognitionResult({
    required this.items,
    required this.isFood,
    this.notesFa,
  });

  final List<RecognizedItem> items;
  final bool isFood;
  final String? notesFa;

  factory RecognitionResult.fromJson(Map<String, dynamic> j) =>
      RecognitionResult(
        items: [
          for (final e in (j['items'] as List? ?? const []))
            RecognizedItem.fromJson(e as Map<String, dynamic>),
        ],
        isFood: j['is_food'] as bool? ?? false,
        notesFa: j['notes_fa'] as String?,
      );
}

abstract interface class FoodRecognizer {
  /// [imageBytes]: عکس فشرده‌شده (بخش ۵-۲).
  Future<RecognitionResult> recognize(List<int> imageBytes);
}

/// پیاده‌سازی جعلی با پاسخ ثابت؛ برای توسعه‌ی UI و تست.
/// food_idها نمونه‌اند و مقدار تغذیه‌ای ندارند.
class FakeFoodRecognizer implements FoodRecognizer {
  FakeFoodRecognizer({RecognitionResult? result, this.delay = Duration.zero})
    : result =
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

  final RecognitionResult result;
  final Duration delay;

  @override
  Future<RecognitionResult> recognize(List<int> imageBytes) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}

/// جای خالی برای مدل روی گوشی (بخش ۸-۶، P2).
class OnDeviceRecognizer implements FoodRecognizer {
  @override
  Future<RecognitionResult> recognize(List<int> imageBytes) =>
      throw UnimplementedError('OnDeviceRecognizer در P2 پیاده می‌شود.');
}
