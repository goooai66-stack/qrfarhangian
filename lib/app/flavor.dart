import 'package:flutter/services.dart' show appFlavor;

/// فروشگاه هدف بر اساس Build Flavor (`--flavor bazaar` یا `--flavor myket`).
enum Store { bazaar, myket, unknown }

Store get currentStore => switch (appFlavor) {
  'bazaar' => Store.bazaar,
  'myket' => Store.myket,
  _ => Store.unknown,
};
