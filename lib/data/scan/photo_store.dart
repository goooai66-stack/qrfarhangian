import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// ذخیره‌ی عکس غذا روی خود گوشی (برای عکس کوچک در فهرست وعده‌ها و صف
/// آفلاین). عکس‌ها فقط محلی‌اند.
class PhotoStore {
  PhotoStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  Future<Directory> _dir() async {
    final d = Directory('${(await _baseDir()).path}/scans');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  Future<String> save(Uint8List jpeg) async {
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32)}.jpg';
    final f = File('${(await _dir()).path}/$name');
    await f.writeAsBytes(jpeg, flush: true);
    return f.path;
  }

  Future<Uint8List?> read(String path) async {
    final f = File(path);
    return f.existsSync() ? f.readAsBytes() : null;
  }

  /// همه‌ی عکس‌های ذخیره‌شده‌ی اپ (برای «حذف همه‌ی داده‌ها»).
  Future<void> deleteAll() async {
    final d = await _dir();
    if (d.existsSync()) await d.delete(recursive: true);
  }

  Future<void> delete(String path) async {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }
}
