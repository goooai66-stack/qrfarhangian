import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../app/providers.dart';
import '../../core/nutrition/nutrition_calculator.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';
import '../common/choice_card.dart';
import '../monetization/paywall_screen.dart';
import '../common/wheel_pickers.dart';
import '../profile/profile_draft.dart';
import '../profile/profile_labels.dart';
import 'plan_result_view.dart';

enum OnboardingStep {
  sex,
  birthDate,
  pregnancy,
  height,
  weight,
  goal,
  goalWeight,
  rate,
  activity,
  result,
}

/// قدم‌های قابل نمایش برای این پیش‌نویس (بارداری فقط برای زن، وزن هدف و
/// سرعت فقط برای کاهش/افزایش).
List<OnboardingStep> visibleSteps(ProfileDraft d) => [
  OnboardingStep.sex,
  OnboardingStep.birthDate,
  if (d.isFemale) OnboardingStep.pregnancy,
  OnboardingStep.height,
  OnboardingStep.weight,
  OnboardingStep.goal,
  if (d.goalType != GoalType.maintain) ...[
    OnboardingStep.goalWeight,
    OnboardingStep.rate,
  ],
  OnboardingStep.activity,
  OnboardingStep.result,
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final DateTime _now = DateTime.now();
  late ProfileDraft _d = ProfileDraft.initial(_now);
  OnboardingStep _step = OnboardingStep.sex;
  bool _saving = false;

  List<OnboardingStep> get _steps => visibleSteps(_d);
  int get _index => _steps.indexOf(_step);

  bool get _canNext => switch (_step) {
    OnboardingStep.sex => _d.sex != null,
    OnboardingStep.goalWeight => _d.isGoalWeightValid,
    _ => true,
  };

  void _update(ProfileDraft d) => setState(() => _d = d);

  void _next() {
    // قوانین ایمنی را قبل از رفتن به قدم بعد اعمال کن.
    setState(() {
      _d = _d.normalized(_now);
      final steps = _steps;
      final i = steps.indexOf(_step);
      if (i < steps.length - 1) _step = steps[i + 1];
    });
  }

  void _back() {
    if (_index > 0) setState(() => _step = _steps[_index - 1]);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final d = _d.normalized(_now);
    await ref
        .read(profileRepositoryProvider)
        .saveOnboarding(d.toInput(), d.plan(_now));
    await ref
        .read(databaseProvider)
        .setSetting(SoftPaywallGate.pendingKey, 'pending');
    if (!mounted) return;
    ref.read(onboardingDoneProvider.notifier).markDone();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final steps = _steps;
    final isResult = _step == OnboardingStep.result;

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _index > 0
              ? IconButton(
                  tooltip: t.back,
                  icon: const BackButtonIcon(),
                  onPressed: _back,
                )
              : null,
          title: Text(
            t.stepOf(
              toPersianDigits('${_index + 1}'),
              toPersianDigits('${steps.length}'),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (_index + 1) / steps.length),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: isResult
                  ? PlanResultView(draft: _d, plan: _d.plan(_now), now: _now)
                  : _buildQuestion(context, t),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              key: const Key('onboarding-next'),
              onPressed: _saving
                  ? null
                  : isResult
                  ? _finish
                  : _canNext
                  ? _next
                  : null,
              child: Text(isResult ? t.resultStart : t.next),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, AppLocalizations t) {
    final (title, body) = switch (_step) {
      OnboardingStep.sex => (t.qSex, _sex(t)),
      OnboardingStep.birthDate => (t.qBirthDate, _birthDate(t)),
      OnboardingStep.pregnancy => (t.qPregnancy, _pregnancy(t)),
      OnboardingStep.height => (t.qHeight, _height(t)),
      OnboardingStep.weight => (t.qWeight, _weight(t)),
      OnboardingStep.goal => (t.qGoal, _goal(t)),
      OnboardingStep.goalWeight => (t.qGoalWeight, _goalWeight(t)),
      OnboardingStep.rate => (t.qRate, _rate(t)),
      OnboardingStep.activity => (t.qActivity, _activity(t)),
      OnboardingStep.result => ('', const SizedBox.shrink()),
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        body,
      ],
    );
  }

  Widget _sex(AppLocalizations t) => Column(
    children: [
      for (final s in Sex.values)
        ChoiceCard(
          title: t.sexLabel(s),
          icon: s == Sex.male ? Icons.male : Icons.female,
          selected: _d.sex == s,
          onTap: () => _update(
            _d.copyWith(
              sex: s,
              heightCm: s == Sex.male ? 175 : 165,
              weightKg: s == Sex.male ? 80 : 70,
            ),
          ),
        ),
    ],
  );

  Widget _birthDate(AppLocalizations t) {
    final jy = Jalali.fromDateTime(_now).year;
    return Column(
      children: [
        JalaliDateWheel(
          value: _d.birthDate,
          minYear: jy - maxAgeYears,
          maxYear: jy - minAgeYears,
          onChanged: (d) => _update(_d.copyWith(birthDate: d)),
        ),
        const SizedBox(height: 16),
        Text(
          t.ageYears(toPersianDigits('${_d.age(_now)}')),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _pregnancy(AppLocalizations t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ChoiceCard(
        title: t.no,
        selected: !_d.isPregnant,
        onTap: () => _update(_d.copyWith(isPregnant: false)),
      ),
      ChoiceCard(
        title: t.yes,
        selected: _d.isPregnant,
        onTap: () => _update(_d.copyWith(isPregnant: true)),
      ),
      const SizedBox(height: 12),
      Text(t.pregnancyHint),
    ],
  );

  Widget _height(AppLocalizations t) => Column(
    children: [
      NumberWheel(
        values: steppedValues(minHeightCm, maxHeightCm, 1),
        value: _d.heightCm,
        onChanged: (v) => _update(_d.copyWith(heightCm: v)),
      ),
      const SizedBox(height: 8),
      Text(t.unitCm),
    ],
  );

  Widget _weight(AppLocalizations t) => Column(
    children: [
      NumberWheel(
        values: steppedValues(minWeightKg, maxWeightKg, weightStep),
        value: _d.weightKg,
        fractionDigits: 1,
        onChanged: (v) => _update(_d.copyWith(weightKg: v)),
      ),
      const SizedBox(height: 8),
      Text(t.unitKg),
      const SizedBox(height: 16),
      Text(t.bmiValue(formatPersianNumber(_d.bmi, fractionDigits: 1))),
    ],
  );

  Widget _goal(AppLocalizations t) {
    final minor = _d.age(_now) < adultAge;
    return Column(
      children: [
        for (final g in GoalType.values)
          Builder(
            builder: (_) {
              final blocked = _d.blockReason(g, _now);
              return ChoiceCard(
                title: t.goalLabel(g, minor: minor),
                icon: switch (g) {
                  GoalType.lose => Icons.trending_down,
                  GoalType.maintain => Icons.trending_flat,
                  GoalType.gain => Icons.trending_up,
                },
                selected: _d.goalType == g && blocked == null,
                enabled: blocked == null,
                disabledReason: blocked == null
                    ? null
                    : t.blockReasonText(blocked),
                onTap: () => _update(_d.copyWith(goalType: g).normalized(_now)),
              );
            },
          ),
      ],
    );
  }

  Widget _goalWeight(AppLocalizations t) {
    final r = _d.goalWeightRange();
    if (r == null) return Text(t.invalidGoalWeight);
    return Column(
      children: [
        NumberWheel(
          // ترتیب: نزدیک‌ترین به وزن فعلی بالا.
          values: _d.goalType == GoalType.lose
              ? steppedValues(r.min, r.max, weightStep).reversed.toList()
              : steppedValues(r.min, r.max, weightStep),
          value: _d.goalWeightKg,
          fractionDigits: 1,
          onChanged: (v) => _update(_d.copyWith(goalWeightKg: v)),
        ),
        const SizedBox(height: 8),
        Text(t.unitKg),
        const SizedBox(height: 16),
        Text(
          t.goalWeightDiff(
            formatPersianNumber(
              (_d.goalWeightKg - _d.weightKg).abs(),
              fractionDigits: 1,
            ),
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          t.goalWeightRange(
            formatPersianNumber(r.min, fractionDigits: 1),
            formatPersianNumber(r.max, fractionDigits: 1),
          ),
        ),
      ],
    );
  }

  Widget _rate(AppLocalizations t) => Column(
    children: [
      for (final rate in allowedWeeklyRates)
        Builder(
          builder: (_) {
            final p = _d.copyWith(weeklyRateKg: rate).plan(_now);
            final floored = p.warnings.contains(PlanWarning.hitSafetyFloor);
            return ChoiceCard(
              title: '${t.rateName(rate)} · ${t.rate(rate)}',
              subtitle: floored
                  ? t.rateFloorHint
                  : t.rateKcal(formatPersianNumber(p.targetKcal)),
              selected: _d.weeklyRateKg == rate,
              onTap: () => _update(_d.copyWith(weeklyRateKg: rate)),
            );
          },
        ),
    ],
  );

  Widget _activity(AppLocalizations t) => Column(
    children: [
      for (final a in ActivityLevel.values)
        ChoiceCard(
          title: t.activityLabel(a),
          subtitle: t.activityDesc(a),
          selected: _d.activityLevel == a,
          onTap: () => _update(_d.copyWith(activityLevel: a)),
        ),
    ],
  );
}
