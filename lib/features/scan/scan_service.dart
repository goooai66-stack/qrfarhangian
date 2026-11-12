import 'package:flutter/foundation.dart';

import '../../core/nutrition/nutrition_types.dart';
import '../../core/recognition/food_recognizer.dart';
import '../../core/utils/image_compress.dart';
import '../../data/scan/pending_scan_repository.dart';
import '../../data/scan/photo_store.dart';

/// نتیجه‌ی یک تلاش اسکن.
sealed class ScanOutcome {
  const ScanOutcome();
}

class ScanSucceeded extends ScanOutcome {
  const ScanSucceeded(this.result, this.jpeg);
  final RecognitionResult result;
  final Uint8List jpeg;
}

/// اینترنت نبود؛ عکس در صف آفلاین ذخیره شد.
class ScanQueued extends ScanOutcome {
  const ScanQueued(this.pendingId);
  final int pendingId;
}

class ScanFailed extends ScanOutcome {
  const ScanFailed(this.kind, this.jpeg);
  final ApiErrorKind kind;
  final Uint8List? jpeg;
}

/// عکس قابل خواندن نیست.
class ScanBadImage extends ScanOutcome {
  const ScanBadImage();
}

/// جریان اسکن (بخش ۵-۲): فشرده‌سازی ← تشخیص ← یا صف آفلاین.
class ScanService {
  ScanService({
    required this.recognizer,
    required this.photos,
    required this.pending,
    this.compress = _compressInIsolate,
  });

  final FoodRecognizer recognizer;
  final PhotoStore photos;
  final PendingScanRepository pending;
  final Future<Uint8List?> Function(Uint8List) compress;

  static Future<Uint8List?> _compressInIsolate(Uint8List raw) =>
      compute(_compress, raw);
  static Uint8List? _compress(Uint8List raw) => compressForScan(raw);

  Future<Uint8List?> prepare(Uint8List raw) => compress(raw);

  Future<ScanOutcome> analyze(
    Uint8List jpeg, {
    required MealType meal,
    required String dayKey,
  }) async {
    try {
      return ScanSucceeded(await recognizer.recognize(jpeg), jpeg);
    } on RecognitionException catch (e) {
      if (e.kind == ApiErrorKind.offline) {
        final path = await photos.save(jpeg);
        final id = await pending.enqueue(
          photoPath: path,
          meal: meal,
          dayKey: dayKey,
        );
        return ScanQueued(id);
      }
      return ScanFailed(e.kind, jpeg);
    }
  }
}
