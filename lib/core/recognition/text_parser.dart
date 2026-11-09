/// ثبت صوتی و متنی (بخش ۸-۴): جمله ← همان نتیجه‌ی اسکن ← همان صفحه‌ی ScanResult.
library;

import '../../data/api/api_client.dart';
import '../nutrition/nutrition_types.dart';
import 'food_recognizer.dart';

abstract interface class TextFoodParser {
  Future<RecognitionResult> parse(String text);
}

class CloudTextParser implements TextFoodParser {
  CloudTextParser(this._api);
  final ApiClient _api;

  @override
  Future<RecognitionResult> parse(String text) async {
    try {
      return RecognitionResult.fromJson(await _api.voice(text));
    } on ApiException catch (e) {
      throw RecognitionException(e.kind, e.detail);
    } on TypeError catch (e) {
      throw RecognitionException(ApiErrorKind.server, '$e');
    }
  }
}

/// نسخه‌ی جعلی برای توسعه و تست.
class FakeTextParser implements TextFoodParser {
  FakeTextParser({RecognitionResult? result, this.error})
    : result =
          result ??
          const RecognitionResult(
            isFood: true,
            meal: MealType.lunch,
            items: [
              RecognizedItem(
                foodId: 'gheymeh',
                nameFa: 'قیمه',
                quantity: 1,
                unit: 'ladle',
                confidence: 0.8,
              ),
              RecognizedItem(
                foodId: 'chelo',
                nameFa: 'برنج',
                quantity: 1,
                unit: 'kafgir',
                confidence: 0.8,
              ),
              RecognizedItem(
                foodId: 'doogh',
                nameFa: 'دوغ',
                quantity: 1,
                unit: 'glass',
                confidence: 0.9,
              ),
            ],
          );

  RecognitionResult result;
  RecognitionException? error;
  final texts = <String>[];

  @override
  Future<RecognitionResult> parse(String text) async {
    texts.add(text);
    if (error != null) throw error!;
    return result;
  }
}
