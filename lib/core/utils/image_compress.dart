/// فشرده‌سازی عکس غذا در گوشی (بخش ۵-۲): حداکثر ضلع ۱۰۲۴ پیکسل،
/// JPEG با کیفیت ۷۵ و زیر ۲۰۰ کیلوبایت. خالص Dart (بدون کد بومی)؛
/// در isolate جدا اجرا شود (compute).
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

const scanMaxSide = 1024;
const scanJpegQuality = 75;
const scanMaxBytes = 200 * 1024;

/// null یعنی فایل عکس قابل خواندن نیست.
Uint8List? compressForScan(
  Uint8List input, {
  int maxSide = scanMaxSide,
  int quality = scanJpegQuality,
  int maxBytes = scanMaxBytes,
}) {
  var image = img.decodeImage(input);
  if (image == null) return null;
  // چرخش EXIF را اعمال کن تا عکس عمودی کج نرود.
  image = img.bakeOrientation(image);

  img.Image resized(img.Image src, int side) {
    final longest = src.width > src.height ? src.width : src.height;
    if (longest <= side) return src;
    return src.width >= src.height
        ? img.copyResize(
            src,
            width: side,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            src,
            height: side,
            interpolation: img.Interpolation.average,
          );
  }

  var side = maxSide;
  var current = resized(image, side);
  var q = quality;
  var out = img.encodeJpg(current, quality: q);
  // اول کیفیت را کم کن (تا ۴۵)، بعد ابعاد را.
  while (out.length > maxBytes) {
    if (q > 45) {
      q -= 10;
    } else {
      side = (side * 0.8).round();
      if (side < 320) break;
      current = resized(image, side);
    }
    out = img.encodeJpg(current, quality: q);
  }
  return out;
}
