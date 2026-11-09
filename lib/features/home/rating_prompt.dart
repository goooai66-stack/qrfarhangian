import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/flavor.dart';
import '../../app/providers.dart';
import '../../core/progress/rating_policy.dart';
import '../../l10n/app_localizations.dart';

const _stateKey = 'rating_state';
const _askedKey = 'rating_asked_at';

/// بعد از ۳ روز استفاده‌ی موفق، یک‌بار در هر اجرای اپ بررسی می‌شود که
/// درخواست امتیاز نشان داده شود یا نه (بخش ۴-۷). بدون اصرار.
class RatingPromptGate extends ConsumerStatefulWidget {
  const RatingPromptGate({super.key});

  /// در هر اجرای اپ حداکثر یک‌بار.
  static bool checkedThisSession = false;

  @override
  ConsumerState<RatingPromptGate> createState() => _RatingPromptGateState();
}

class _RatingPromptGateState extends ConsumerState<RatingPromptGate> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(loggedDaysProvider, (_, next) {
      final days = next.value;
      if (days == null || RatingPromptGate.checkedThisSession) return;
      if (days.length < ratingMinLoggedDays) return;
      RatingPromptGate.checkedThisSession = true;
      _maybeAsk(days.length);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  Future<void> _maybeAsk(int loggedDays) async {
    final db = ref.read(databaseProvider);
    final saved = await db.getSetting(_stateKey);
    final state =
        RatingState.values.where((s) => s.name == saved).firstOrNull ??
        RatingState.none;
    final askedRaw = await db.getSetting(_askedKey);
    final ask = shouldAskForRating(
      loggedDays: loggedDays,
      state: state,
      lastAsked: askedRaw == null ? null : DateTime.tryParse(askedRaw),
      now: DateTime.now(),
    );
    if (!ask || !mounted) return;
    final t = AppLocalizations.of(context);
    final store = switch (currentStore) {
      Store.bazaar => t.storeBazaar,
      Store.myket => t.storeMyket,
      Store.unknown => t.storeGeneric,
    };
    final choice = await showDialog<RatingState>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.rateTitle),
        content: Text(t.rateBody(store)),
        actions: [
          TextButton(
            key: const Key('rate-never'),
            onPressed: () => Navigator.pop(c, RatingState.never),
            child: Text(t.rateNever),
          ),
          TextButton(
            key: const Key('rate-later'),
            onPressed: () => Navigator.pop(c, RatingState.later),
            child: Text(t.rateLater),
          ),
          FilledButton(
            key: const Key('rate-yes'),
            onPressed: () => Navigator.pop(c, RatingState.done),
            child: Text(t.rateYes),
          ),
        ],
      ),
    );
    final result = choice ?? RatingState.later;
    await db.setSetting(_stateKey, result.name);
    await db.setSetting(_askedKey, DateTime.now().toIso8601String());
    if (result == RatingState.done) {
      await ref.read(storeRatingProvider).open();
    }
  }
}
