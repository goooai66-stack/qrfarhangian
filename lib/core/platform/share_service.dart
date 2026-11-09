import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// اشتراک کارت (تلگرام، اینستاگرام، …). فقط با انتخاب خود کاربر.
abstract interface class ShareService {
  Future<void> shareImage(Uint8List png, {String? text});
}

class SystemShareService implements ShareService {
  @override
  Future<void> shareImage(Uint8List png, {String? text}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/calorielens_card.png');
    await file.writeAsBytes(png, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
      ),
    );
  }
}

class FakeShareService implements ShareService {
  final shared = <Uint8List>[];
  String? lastText;

  @override
  Future<void> shareImage(Uint8List png, {String? text}) async {
    shared.add(png);
    lastText = text;
  }
}
