import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../app/providers.dart';
import '../../core/nutrition/nutrition_calculator.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';
import '../common/wheel_pickers.dart';
import 'profile_draft.dart';
import 'profile_labels.dart';
import '../../l10n/date_names.dart';

/// ویرایش پروفایل و هدف با پیش‌نمایش زنده‌ی کالری؛ ذخیره = هدف جدید در تاریخچه.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final DateTime _now = DateTime.now();
  ProfileDraft? _d;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(profileRepositoryProvider);
    final p = await repo.getProfile();
    final w = await repo.watchCurrentWeight().first;
    if (!mounted) return;
    setState(
      () => _d = p == null
          ? ProfileDraft.initial(_now).copyWith(sex: Sex.female)
          : ProfileDraft.fromProfile(p, currentWeightKg: w),
    );
  }

  /// تغییر + اعمال قوانین ایمنی.
  void _set(ProfileDraft d) => setState(() => _d = d.normalized(_now));

  Future<void> _save() async {
    final d = _d!.normalized(_now);
    setState(() => _saving = true);
    await ref
        .read(profileRepositoryProvider)
        .updateProfile(d.toInput(), d.plan(_now));
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.saved)));
    context.pop();
  }

  Future<T?> _sheet<T>(Widget Function(void Function(T) pick) builder) =>
      showModalBottomSheet<T>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: builder((v) => Navigator.of(c).pop(v)),
          ),
        ),
      );

  /// برگه‌ی چرخ با دکمه‌ی تأیید.
  Future<T?> _wheelSheet<T>(T initial, Widget Function(ValueChanged<T>) wheel) {
    var current = initial;
    final t = AppLocalizations.of(context);
    return _sheet<T>(
      (pick) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          wheel((v) => current = v),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => pick(current),
              child: Text(t.confirm),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final d = _d;
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final plan = d.plan(_now);
    final minor = d.age(_now) < adultAge;
    final jy = Jalali.fromDateTime(_now).year;

    return Scaffold(
      appBar: AppBar(title: Text(t.profileEdit)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<Sex>(
              segments: [
                for (final s in Sex.values)
                  ButtonSegment(value: s, label: Text(t.sexLabel(s))),
              ],
              selected: {d.sex ?? Sex.female},
              onSelectionChanged: (s) => _set(d.copyWith(sex: s.first)),
            ),
          ),
          ListTile(
            title: Text(t.profileBirthDate),
            trailing: Text(
              '${t.formatDateLong(d.birthDate)} '
              '(${t.ageYears(toPersianDigits('${d.age(_now)}'))})',
            ),
            onTap: () async {
              final v = await _wheelSheet<DateTime>(
                d.birthDate,
                (onChanged) => _StatefulDateWheel(
                  initial: d.birthDate,
                  minYear: jy - maxAgeYears,
                  maxYear: jy - minAgeYears,
                  onChanged: onChanged,
                ),
              );
              if (v != null) _set(_d!.copyWith(birthDate: v));
            },
          ),
          if (d.isFemale)
            SwitchListTile(
              title: Text(t.profilePregnant),
              subtitle: Text(t.pregnancyHint),
              value: d.isPregnant,
              onChanged: (v) => _set(d.copyWith(isPregnant: v)),
            ),
          ListTile(
            title: Text(t.profileHeight),
            trailing: Text(t.cm(d.heightCm)),
            onTap: () async {
              final v = await _wheelSheet<double>(
                d.heightCm,
                (onChanged) => _StatefulNumberWheel(
                  values: steppedValues(minHeightCm, maxHeightCm, 1),
                  initial: d.heightCm,
                  onChanged: onChanged,
                ),
              );
              if (v != null) _set(_d!.copyWith(heightCm: v));
            },
          ),
          ListTile(
            title: Text(t.profileCurrentWeight),
            trailing: Text(t.kg(d.weightKg)),
            onTap: () async {
              final v = await _wheelSheet<double>(
                d.weightKg,
                (onChanged) => _StatefulNumberWheel(
                  values: steppedValues(minWeightKg, maxWeightKg, weightStep),
                  initial: d.weightKg,
                  fractionDigits: 1,
                  onChanged: onChanged,
                ),
              );
              if (v != null) _set(_d!.copyWith(weightKg: v));
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(t.profileGoal),
          ),
          RadioGroup<GoalType>(
            groupValue: d.goalType,
            onChanged: (v) {
              if (v != null) _set(d.copyWith(goalType: v));
            },
            child: Column(
              children: [
                for (final g in GoalType.values)
                  Builder(
                    builder: (_) {
                      final blocked = d.blockReason(g, _now);
                      return RadioListTile<GoalType>(
                        key: Key('edit-goal-${g.name}'),
                        value: g,
                        enabled: blocked == null,
                        title: Text(t.goalLabel(g, minor: minor)),
                        subtitle: blocked == null
                            ? null
                            : Text(t.blockReasonText(blocked)),
                      );
                    },
                  ),
              ],
            ),
          ),
          if (d.goalType != GoalType.maintain) ...[
            ListTile(
              title: Text(t.profileGoalWeight),
              trailing: Text(t.kg(d.goalWeightKg)),
              onTap: () async {
                final r = d.goalWeightRange();
                if (r == null) return;
                final v = await _wheelSheet<double>(
                  d.goalWeightKg,
                  (onChanged) => _StatefulNumberWheel(
                    values: steppedValues(r.min, r.max, weightStep),
                    initial: d.goalWeightKg,
                    fractionDigits: 1,
                    onChanged: onChanged,
                  ),
                );
                if (v != null) _set(_d!.copyWith(goalWeightKg: v));
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(t.profileRate),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<double>(
                segments: [
                  for (final r in allowedWeeklyRates)
                    ButtonSegment(
                      value: r,
                      label: Text(formatPersianNumber(r, fractionDigits: 2)),
                    ),
                ],
                selected: {d.weeklyRateKg},
                onSelectionChanged: (s) =>
                    _set(d.copyWith(weeklyRateKg: s.first)),
              ),
            ),
          ],
          const Divider(),
          ListTile(
            title: Text(t.profileActivity),
            trailing: DropdownButton<ActivityLevel>(
              value: d.activityLevel,
              underline: const SizedBox.shrink(),
              items: [
                for (final a in ActivityLevel.values)
                  DropdownMenuItem(value: a, child: Text(t.activityLabel(a))),
              ],
              onChanged: (a) => _set(d.copyWith(activityLevel: a)),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.local_fire_department_outlined),
              title: Text(
                t.editPreview(formatPersianNumber(plan.targetKcal)),
                key: const Key('edit-preview'),
              ),
              subtitle: Text(
                '${t.macroProtein} ${t.grams(plan.proteinG)} · '
                '${t.macroCarbs} ${t.grams(plan.carbsG)} · '
                '${t.macroFat} ${t.grams(plan.fatG)}',
              ),
            ),
          ),
          for (final w in plan.warnings)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(t.warningText(w)),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              t.medicalDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            key: const Key('profile-save'),
            onPressed: _saving || !d.isGoalWeightValid ? null : _save,
            child: Text(t.save),
          ),
        ),
      ),
    );
  }
}

/// چرخ عددی که وضعیت خودش را داخل برگه نگه می‌دارد.
class _StatefulNumberWheel extends StatefulWidget {
  const _StatefulNumberWheel({
    required this.values,
    required this.initial,
    required this.onChanged,
    this.fractionDigits = 0,
  });

  final List<double> values;
  final double initial;
  final ValueChanged<double> onChanged;
  final int fractionDigits;

  @override
  State<_StatefulNumberWheel> createState() => _StatefulNumberWheelState();
}

class _StatefulNumberWheelState extends State<_StatefulNumberWheel> {
  late double _v = widget.initial;

  @override
  Widget build(BuildContext context) => NumberWheel(
    values: widget.values,
    value: _v,
    fractionDigits: widget.fractionDigits,
    onChanged: (v) {
      setState(() => _v = v);
      widget.onChanged(v);
    },
  );
}

class _StatefulDateWheel extends StatefulWidget {
  const _StatefulDateWheel({
    required this.initial,
    required this.minYear,
    required this.maxYear,
    required this.onChanged,
  });

  final DateTime initial;
  final int minYear;
  final int maxYear;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_StatefulDateWheel> createState() => _StatefulDateWheelState();
}

class _StatefulDateWheelState extends State<_StatefulDateWheel> {
  late DateTime _v = widget.initial;

  @override
  Widget build(BuildContext context) => JalaliDateWheel(
    value: _v,
    minYear: widget.minYear,
    maxYear: widget.maxYear,
    onChanged: (v) {
      setState(() => _v = v);
      widget.onChanged(v);
    },
  );
}
