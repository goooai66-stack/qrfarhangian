import 'dart:math';
import 'dart:typed_data';

import 'package:calorie_lens/core/utils/image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// تصویر نویزی (سخت برای فشرده‌سازی) با ابعاد داده‌شده.
Uint8List noisyJpeg(int w, int h, {int quality = 95}) {
  final r = Random(1);
  final im = img.Image(width: w, height: h);
  for (final p in im) {
    p
      ..r = r.nextInt(256)
      ..g = r.nextInt(256)
      ..b = r.nextInt(256);
  }
  return img.encodeJpg(im, quality: quality);
}

void main() {
  test('بزرگ و نویزی ← ضلع بلند ≤ ۱۰۲۴ و زیر ۲۰۰ کیلوبایت', () {
    final input = noisyJpeg(2000, 1500);
    expect(input.length, greaterThan(scanMaxBytes));
    final out = compressForScan(input)!;
    expect(out.length, lessThanOrEqualTo(scanMaxBytes));
    expect(out.sublist(0, 3), [0xFF, 0xD8, 0xFF]); // JPEG
    final decoded = img.decodeJpg(out)!;
    expect(max(decoded.width, decoded.height), lessThanOrEqualTo(1024));
    // نسبت ابعاد حفظ می‌شود.
    expect(decoded.width / decoded.height, closeTo(2000 / 1500, 0.01));
  });

  test('عکس عمودی', () {
    final out = compressForScan(noisyJpeg(600, 1400))!;
    final d = img.decodeJpg(out)!;
    expect(d.height, lessThanOrEqualTo(1024));
    expect(d.height, greaterThan(d.width));
  });

  test('عکس کوچک بزرگ نمی‌شود', () {
    final out = compressForScan(noisyJpeg(300, 200))!;
    final d = img.decodeJpg(out)!;
    expect(d.width, 300);
  });

  test('فایل نامعتبر ← null', () {
    expect(compressForScan(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
