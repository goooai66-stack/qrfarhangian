import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class CalorieLensApp extends ConsumerStatefulWidget {
  const CalorieLensApp({super.key});

  @override
  ConsumerState<CalorieLensApp> createState() => _CalorieLensAppState();
}

class _CalorieLensAppState extends ConsumerState<CalorieLensApp> {
  late final ValueNotifier<bool> _onboardingDone = ValueNotifier(
    ref.read(onboardingDoneProvider),
  );
  late final GoRouter _router = buildRouter(_onboardingDone);

  late final AppLifecycleListener _lifecycle;
  Timer? _queueTimer;

  @override
  void initState() {
    super.initState();
    // صف اسکن آفلاین: هنگام باز شدن، برگشت به اپ و هر دقیقه.
    _lifecycle = AppLifecycleListener(onResume: _processQueue);
    WidgetsBinding.instance.addPostFrameCallback((_) => _processQueue());
    _queueTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _processQueue(),
    );
  }

  Future<void> _processQueue() async {
    if (!mounted || !ref.read(onboardingDoneProvider)) return;
    try {
      await ref.read(pendingScanProcessorProvider).processAll();
    } catch (e, st) {
      debugPrint('pending scans: $e\n$st');
    }
  }

  @override
  void dispose() {
    _queueTimer?.cancel();
    _lifecycle.dispose();
    _router.dispose();
    _onboardingDone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      onboardingDoneProvider,
      (_, done) => _onboardingDone.value = done,
    );
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      // فارسی و راست‌به‌چپ؛ جهت از locale «fa» به‌طور خودکار RTL می‌شود.
      locale: const Locale('fa'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
