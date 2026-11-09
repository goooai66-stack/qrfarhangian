import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/reminders/reminder_plan.dart';
import '../../core/reminders/reminder_scheduler.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/date_names.dart';

/// متن اعلان‌ها از فایل ترجمه.
ReminderTexts reminderTexts(AppLocalizations t) => {
  ReminderKind.breakfast: (
    title: t.notifBreakfastTitle,
    body: t.notifBreakfastBody,
  ),
  ReminderKind.lunch: (title: t.notifLunchTitle, body: t.notifLunchBody),
  ReminderKind.dinner: (title: t.notifDinnerTitle, body: t.notifDinnerBody),
  ReminderKind.water: (title: t.notifWaterTitle, body: t.notifWaterBody),
  ReminderKind.weight: (title: t.notifWeightTitle, body: t.notifWeightBody),
};

String formatHM(TimeOfDayHM t) => toPersianDigits(
  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
);

/// تنظیم یادآورها (ساعت قابل تنظیم و قابل خاموش شدن، بخش ۴-۵).
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  Future<void> _update(ReminderSettings next) async {
    final t = AppLocalizations.of(context);
    final scheduler = ref.read(reminderSchedulerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final prev = ref.read(reminderSettingsProvider).value;
    final turningOn = next.anyEnabled && !(prev?.anyEnabled ?? false);
    if (turningOn && !await scheduler.requestPermission()) {
      messenger.showSnackBar(SnackBar(content: Text(t.remindPermissionDenied)));
      return;
    }
    await ref.read(reminderSettingsProvider.notifier).save(next);
    await scheduler.apply(next, reminderTexts(t));
  }

  Future<TimeOfDayHM?> _pickTime(TimeOfDayHM initial) async {
    final r = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return r == null ? null : TimeOfDayHM(r.hour, r.minute);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = ref.watch(reminderSettingsProvider).value;
    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget timeTile(
      String label,
      TimeOfDayHM time,
      ReminderSettings Function(TimeOfDayHM) set,
    ) => ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 16),
      title: Text(label),
      trailing: Text(
        formatHM(time),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () async {
        final v = await _pickTime(time);
        if (v != null) await _update(set(v));
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.remindersTitle)),
      body: ListView(
        children: [
          SwitchListTile(
            key: const Key('remind-meals'),
            title: Text(t.remindMeals),
            value: s.meals,
            onChanged: (v) => _update(s.copyWith(meals: v)),
          ),
          if (s.meals) ...[
            timeTile(
              t.mealBreakfast,
              s.breakfast,
              (v) => s.copyWith(breakfast: v),
            ),
            timeTile(t.mealLunch, s.lunch, (v) => s.copyWith(lunch: v)),
            timeTile(t.mealDinner, s.dinner, (v) => s.copyWith(dinner: v)),
          ],
          const Divider(),
          SwitchListTile(
            key: const Key('remind-water'),
            title: Text(t.remindWater),
            subtitle: Text(
              t.remindWaterEvery(
                toPersianDigits('${s.waterEveryHours}'),
                formatHM(TimeOfDayHM(s.waterStartHour, 0)),
                formatHM(TimeOfDayHM(s.waterEndHour, 0)),
              ),
            ),
            value: s.water,
            onChanged: (v) => _update(s.copyWith(water: v)),
          ),
          if (s.water)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 32, end: 16),
              child: SegmentedButton<int>(
                segments: [
                  for (final h in [1, 2, 3])
                    ButtonSegment(value: h, label: Text(toPersianDigits('$h'))),
                ],
                selected: {s.waterEveryHours},
                onSelectionChanged: (v) =>
                    _update(s.copyWith(waterEveryHours: v.first)),
              ),
            ),
          const Divider(),
          SwitchListTile(
            key: const Key('remind-weight'),
            title: Text(t.remindWeight),
            value: s.weight,
            onChanged: (v) => _update(s.copyWith(weight: v)),
          ),
          if (s.weight) ...[
            ListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: 32,
                end: 16,
              ),
              title: DropdownButton<int>(
                value: s.weightWeekday,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: [
                  // DateTime: شنبه=۶ … جمعه=۵؛ نمایش از شنبه.
                  for (var i = 0; i < 7; i++)
                    DropdownMenuItem(
                      value: (i + 5) % 7 + 1,
                      child: Text(t.weekdays[i]),
                    ),
                ],
                onChanged: (v) => _update(s.copyWith(weightWeekday: v)),
              ),
            ),
            timeTile(
              t.logWeight,
              s.weightTime,
              (v) => s.copyWith(weightTime: v),
            ),
          ],
        ],
      ),
    );
  }
}
