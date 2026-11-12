import 'package:flutter/services.dart';

import '../../app/flavor.dart';

/// باز کردن صفحه‌ی امتیاز در کافه‌بازار یا مایکت (بر اساس Flavor).
abstract interface class StoreRating {
  Future<bool> open();
}

class ChannelStoreRating implements StoreRating {
  static const _channel = MethodChannel('calorielens/store');

  @override
  Future<bool> open() async {
    final store = switch (currentStore) {
      Store.bazaar => 'bazaar',
      Store.myket => 'myket',
      Store.unknown => null,
    };
    if (store == null) return false;
    try {
      return await _channel.invokeMethod<bool>('rate', {'store': store}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

class FakeStoreRating implements StoreRating {
  int opened = 0;

  @override
  Future<bool> open() async {
    opened++;
    return true;
  }
}
