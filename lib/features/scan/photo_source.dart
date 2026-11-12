import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum ScanSource { camera, gallery }

/// منبع عکس؛ در تست با نسخه‌ی جعلی جایگزین می‌شود.
abstract interface class PhotoSource {
  /// null یعنی کاربر انصراف داد.
  Future<Uint8List?> pick(ScanSource source);
}

/// دوربین و گالری سیستم. image_picker از همان ابتدا ابعاد و کیفیت را
/// محدود می‌کند؛ فشرده‌سازی نهایی در [compressForScan] انجام می‌شود.
class ImagePickerPhotoSource implements PhotoSource {
  final _picker = ImagePicker();

  @override
  Future<Uint8List?> pick(ScanSource source) async {
    final file = await _picker.pickImage(
      source: source == ScanSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }
}
