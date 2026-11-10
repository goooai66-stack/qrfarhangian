import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';
import '../../app/providers.dart';
import '../../core/platform/home_widget_service.dart';
import '../../core/reminders/reminder_plan.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';
import '../home/rating_prompt.dart';

/// درباره، سلب مسئولیت پزشکی، حریم خصوصی، آمار ناشناس و «حذف همه‌ی داده‌ها».
class InfoScreen extends ConsumerStatefulWidget {
  const InfoScreen({super.key});

  @override
  ConsumerState<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends ConsumerState<InfoScreen> {
  bool? _analytics;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).isEnabled().then((v) {
      if (mounted) setState(() => _analytics = v);
    });
  }

  void _showText(String title, String body) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SelectableText(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8),
          ),
        ),
      ),
    ),
  );

  Future<void> _deleteAll() async {
    final t = AppLocalizations.of(context);
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: Text(t.deleteAllData),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.deleteAllDesc),
              const SizedBox(height: 12),
              Text(t.deleteAllConfirm),
              TextField(
                key: const Key('delete-confirm-input'),
                controller: c,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(t.cancel),
            ),
            FilledButton(
              key: const Key('delete-confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(d).colorScheme.error,
              ),
              onPressed: c.text.trim() == t.deleteAllWord
                  ? () => Navigator.pop(d, true)
                  : null,
              child: Text(t.deleteItem),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final serverOk = await wipeAllData(ref);
    messenger.showSnackBar(
      SnackBar(
        content: Text(serverOk ? t.deleteAllDone : t.deleteAllServerFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.openSettingsInfo)),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: Text(
              t.appTitle,
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Center(child: Text(t.aboutTagline)),
          Center(
            child: Text(
              t.aboutVersion(toPersianDigits(AppConfig.version)),
              key: const Key('app-version'),
              style: tt.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            key: const Key('open-disclaimer'),
            leading: const Icon(Icons.health_and_safety_outlined),
            title: Text(t.disclaimerTitle),
            onTap: () => _showText(t.disclaimerTitle, t.disclaimerBody),
          ),
          ListTile(
            key: const Key('open-privacy'),
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(t.privacyTitle),
            onTap: () => _showText(t.privacyTitle, t.privacyBody),
          ),
          SwitchListTile(
            key: const Key('analytics-toggle'),
            secondary: const Icon(Icons.insights_outlined),
            title: Text(t.analyticsToggle),
            subtitle: Text(t.analyticsToggleDesc),
            value: _analytics ?? true,
            onChanged: _analytics == null
                ? null
                : (v) async {
                    await ref.read(analyticsProvider).setEnabled(v);
                    setState(() => _analytics = v);
                  },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(t.licenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: t.appTitle,
              applicationVersion: toPersianDigits(AppConfig.version),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            key: const Key('delete-all'),
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              t.deleteAllData,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(t.deleteAllDesc),
            onTap: _deleteAll,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// «حذف همه‌ی داده‌ها»: سرور (اگر در دسترس باشد)، یادآورها، ویجت، عکس‌ها،
/// دیتابیس ← برگشت به آنبوردینگ. خروجی: آیا داده‌های سرور هم پاک شد.
Future<bool> wipeAllData(WidgetRef ref) async {
  var serverOk = true;
  try {
    await ref.read(communityApiProvider).deleteServerData();
  } catch (_) {
    serverOk = false;
  }
  try {
    await ref
        .read(reminderSchedulerProvider)
        .apply(const ReminderSettings(), const {});
  } catch (_) {}
  try {
    await ref.read(photoStoreProvider).deleteAll();
  } catch (_) {}
  await ref.read(databaseProvider).wipeAll();
  try {
    await ref
        .read(homeWidgetServiceProvider)
        .update(
          // ویجت خالی می‌شود.
          const WidgetSnapshot(value: '—', label: '', detail: ''),
        );
  } catch (_) {}
  RatingPromptGate.checkedThisSession = false;
  ref
    ..invalidate(entitlementProvider)
    ..invalidate(reminderSettingsProvider)
    ..invalidate(beforeAfterProvider)
    ..invalidate(themeModeProvider)
    ..invalidate(selectedDayProvider);
  ref.read(onboardingDoneProvider.notifier).reset();
  return serverOk;
}
