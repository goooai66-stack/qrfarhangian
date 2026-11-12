import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/units/weight_unit.dart';
import '../../app/router.dart';
import '../../core/nutrition/nutrition_calculator.dart';
import '../../core/utils/persian_digits.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/date_names.dart';
import 'profile_labels.dart';

/// تب «پروفایل»: خلاصه‌ی برنامه، ویرایش، تم و سلب مسئولیت.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);
    final unit = ref.watch(weightUnitProvider);
    final paid = ref.watch(monetizationEnabledProvider);
    final profile = ref.watch(profileProvider).value;
    final goal = ref.watch(activeGoalProvider).value;
    final weight = ref.watch(currentWeightProvider).value;
    final ent = ref.watch(entitlementProvider).value;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.tabProfile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (profile == null || goal == null)
            Text(t.profileNoData)
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.profileSummary, style: tt.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '${formatPersianNumber(goal.kcal)} ${t.kcalUnit}',
                      key: const Key('profile-kcal'),
                      style: tt.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${t.macroProtein} ${t.grams(goal.proteinG)} · '
                      '${t.macroCarbs} ${t.grams(goal.carbsG)} · '
                      '${t.macroFat} ${t.grams(goal.fatG)}',
                    ),
                    const Divider(height: 24),
                    _Row(
                      t.profileGoal,
                      t.goalLabel(
                        profile.goalType,
                        minor:
                            ageInYears(profile.birthDate, DateTime.now()) <
                            adultAge,
                      ),
                    ),
                    if (weight != null)
                      _Row(t.profileCurrentWeight, t.weight(weight, unit)),
                    if (profile.goalType != GoalType.maintain)
                      _Row(
                        t.profileGoalWeight,
                        t.weight(profile.goalWeightKg, unit),
                      ),
                    _Row(
                      t.profileActivity,
                      t.activityLabel(profile.activityLevel),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('profile-edit'),
            onPressed: () => context.push(Routes.profileEdit),
            icon: const Icon(Icons.edit_outlined),
            label: Text(t.profileEdit),
          ),
          const SizedBox(height: 8),
          if (paid) ...[
            Card(
              color: BrandColors.orange.withValues(alpha: 0.12),
              child: ListTile(
                key: const Key('premium-card'),
                leading: const Text('💎', style: TextStyle(fontSize: 24)),
                title: Text(
                  ent?.premium == true && ent?.premiumUntil != null
                      ? t.premiumActiveUntil(
                          t.formatDateLong(ent!.premiumUntil!),
                        )
                      : t.upgradePremium,
                ),
                onTap: ent?.premium == true
                    ? null
                    : () => context.push(Routes.paywall),
              ),
            ),
            Card(
              child: ListTile(
                key: const Key('open-invite'),
                leading: const Icon(Icons.card_giftcard_outlined),
                title: Text(t.inviteTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.invite),
              ),
            ),
          ],
          Card(
            child: ListTile(
              key: const Key('open-reminders'),
              leading: const Icon(Icons.notifications_outlined),
              title: Text(t.remindersTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.reminders),
            ),
          ),
          const SizedBox(height: 24),
          Text(t.themeMode, style: tt.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(t.themeSystem),
                icon: const Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(t.themeLight),
                icon: const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(t.themeDark),
                icon: const Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 24),
          Text(t.weightUnitTitle, style: tt.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<WeightUnit>(
            key: const Key('settings-weight-unit'),
            segments: [
              for (final u in WeightUnit.values)
                ButtonSegment(value: u, label: Text(t.unitName(u))),
            ],
            selected: {unit},
            onSelectionChanged: (s) =>
                ref.read(weightUnitProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(t.medicalDisclaimer),
            ),
          ),
          Card(
            child: ListTile(
              key: const Key('open-info'),
              leading: const Icon(Icons.info_outline),
              title: Text(t.openSettingsInfo),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.info),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
