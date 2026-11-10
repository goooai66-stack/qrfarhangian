import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/db/app_database.dart';
import 'data/profile/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // مجوز OFL فونت Vazirmatn در «مجوزهای نرم‌افزار».
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/Vazirmatn/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Vazirmatn'], ofl);
  });
  final db = AppDatabase();
  // یک کوئری سبک: اگر پروفایل هست، آنبوردینگ تکرار نمی‌شود.
  final done = await ProfileRepository(db).hasProfile();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialOnboardingDoneProvider.overrideWithValue(done),
      ],
      child: const CalorieLensApp(),
    ),
  );
}
