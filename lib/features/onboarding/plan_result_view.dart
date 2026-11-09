import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/nutrition/nutrition_calculator.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';
import '../profile/profile_draft.dart';
import '../profile/profile_labels.dart';
import '../../l10n/date_names.dart';

/// صفحه‌ی نتیجه: کالری روزانه، درشت‌مغذی‌ها، تاریخ رسیدن و نمودار پیش‌بینی.
class PlanResultView extends StatelessWidget {
  const PlanResultView({
    super.key,
    required this.draft,
    required this.plan,
    required this.now,
  });

  final ProfileDraft draft;
  final NutritionPlan plan;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final eta = plan.etaFrom(now);
    final minor = plan.age < adultAge;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          t.resultTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                Text(t.resultDailyKcal, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  formatPersianNumber(plan.targetKcal),
                  key: const Key('result-kcal'),
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(t.kcalUnit, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Macro(
                      label: t.macroProtein,
                      value: t.grams(plan.proteinG),
                      color: BrandColors.green,
                    ),
                    _Macro(
                      label: t.macroCarbs,
                      value: t.grams(plan.carbsG),
                      color: BrandColors.orange,
                    ),
                    _Macro(
                      label: t.macroFat,
                      value: t.grams(plan.fatG),
                      color: theme.colorScheme.tertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (plan.effectiveGoal == GoalType.maintain)
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: Text(
              minor ? t.goalHealthyEating : t.resultMaintain,
              style: theme.textTheme.titleMedium,
            ),
          )
        else if (eta != null) ...[
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: Text(
              t.resultEta(
                formatPersianNumber(draft.goalWeightKg, fractionDigits: 1),
                t.formatDateLong(eta),
              ),
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              t.resultEtaWeeks(formatPersianNumber(plan.weeksToGoal!.round())),
            ),
          ),
          const SizedBox(height: 8),
          Text(t.resultChartTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: WeightProjectionChart(
              startKg: draft.weightKg,
              goalKg: draft.goalWeightKg,
              weeklyRateKg: plan.effectiveWeeklyRateKg,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final w in plan.warnings)
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(t.warningText(w)),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          t.medicalDisclaimer,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: tt.bodyMedium),
          Text(
            value,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// نمودار خطی پیش‌بینی وزن هفته‌به‌هفته با خط هدف.
class WeightProjectionChart extends StatelessWidget {
  const WeightProjectionChart({
    super.key,
    required this.startKg,
    required this.goalKg,
    required this.weeklyRateKg,
  });

  final double startKg;
  final double goalKg;
  final double weeklyRateKg;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final pts = projectWeight(
      startKg: startKg,
      goalKg: goalKg,
      weeklyRateKg: weeklyRateKg,
    );
    final lo = (startKg < goalKg ? startKg : goalKg) - 2;
    final hi = (startKg > goalKg ? startKg : goalKg) + 2;
    final maxX = pts.last.week <= 0 ? 1.0 : pts.last.week;
    final xInterval = (maxX / 4).clamp(1, double.infinity).toDouble();
    final labelStyle = Theme.of(context).textTheme.bodySmall;

    // محور زمان چپ‌به‌راست می‌ماند؛ برچسب‌ها فارسی‌اند.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: lo,
          maxY: hi,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(formatPersianNumber(v), style: labelStyle),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text(t.chartWeekAxis, style: labelStyle),
              axisNameSize: 20,
              sideTitles: SideTitles(
                showTitles: true,
                interval: xInterval,
                reservedSize: 28,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    formatPersianNumber(v.round()),
                    style: labelStyle,
                  ),
                ),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: goalKg,
                color: BrandColors.orange,
                strokeWidth: 1.5,
                dashArray: [6, 4],
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final p in pts) FlSpot(p.week, p.weightKg)],
              color: cs.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: cs.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
