import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/platform/home_widget_service.dart';
import '../features/settings/reminders_screen.dart';
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
    _lifecycle = AppLifecycleListener(onResume: _tick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tick();
      _reapplyReminders();
    });
    _queueTimer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    ref.listenManual(
      widgetSnapshotProvider,
      (prev, next) => next != prev ? _syncWidget(next) : null,
      fireImmediately: true,
    );
  }

  /// هر دقیقه و هنگام برگشت به اپ: صف اسکن + جلو رفتن «امروز» بعد از نیمه‌شب.
  void _tick() {
    if (!mounted) return;
    ref.read(todayProvider.notifier).refresh();
    _processQueue();
  }

  /// یادآورها با منطقه‌ی زمانی فعلی گوشی دوباره زمان‌بندی می‌شوند.
  Future<void> _reapplyReminders() async {
    try {
      final s = await ref.read(reminderSettingsProvider.future);
      if (!s.anyEnabled || !mounted) return;
      final t = lookupAppLocalizations(const Locale('fa'));
      await ref.read(reminderSchedulerProvider).apply(s, reminderTexts(t));
    } catch (e) {
      debugPrint('reminders: $e');
    }
  }

  /// ویجت صفحه‌ی اصلی با هر تغییر کالری امروز به‌روز می‌شود.
  Future<void> _syncWidget(WidgetSnapshot? s) async {
    if (s == null) return;
    try {
      await ref.read(homeWidgetServiceProvider).update(s);
    } catch (e) {
      debugPrint('home widget: $e');
    }
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
