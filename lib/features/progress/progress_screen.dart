import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/nutrition/serving.dart';
import '../../core/progress/badges.dart';
import '../../core/utils/image_compress.dart';
import '../../core/utils/jalali_date.dart';
import '../../core/utils/persian_digits.dart';
import '../../data/db/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/date_names.dart';
import '../common/wheel_pickers.dart';
import '../profile/profile_draft.dart';
import '../profile/profile_labels.dart';
import '../scan/photo_source.dart';
import '../../core/ads/ad_service.dart';
import '../monetization/ad_coordinator.dart';
import 'progress_labels.dart';
import 'share_card.dart';

/// تب «پیشرفت» (بخش ۴-۴ و ۴-۵).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tabProgress)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          const _StreakCard(),
          const _WeightCard(),
          const _CaloriesCard(),
          // نیتیو با برچسب «تبلیغ»، هم‌شکل کارت‌ها (بخش ۹-۲).
          AdSlot(AdPlacement.nativeProgress, label: t.adLabel),
          const _BadgesCard(),
          const _BeforeAfterCard(),
        ],
      ),
    );
  }
}

// ---- زنجیره ----

class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final s = ref.watch(streakProvider);
    final tt = Theme.of(context).textTheme;
    return Card(
      child: ListTile(
        leading: const Text('🔥', style: TextStyle(fontSize: 32)),
        title: Text(
          s.current > 0
              ? t.streakDays(formatPersianNumber(s.current))
              : t.streakZero,
          key: const Key('streak-text'),
          style: s.current > 0 ? tt.titleLarge : tt.bodyLarge,
        ),
        subtitle: s.longest > 0
            ? Text(t.streakRecord(formatPersianNumber(s.longest)))
            : null,
        trailing: s.current >= 3
            ? IconButton(
                key: const Key('share-streak'),
                tooltip: t.shareStreak,
                icon: const Icon(Icons.share),
                onPressed: () => showShareCardDialog(
                  context,
                  ShareCard.streak(streak: s.current),
                ),
              )
            : null,
      ),
    );
  }
}

// ---- وزن ----

class _WeightCard extends ConsumerWidget {
  const _WeightCard();

  Future<void> _logWeight(
    BuildContext context,
    WidgetRef ref,
    double initial,
  ) async {
    final t = AppLocalizations.of(context);
    var value = initial;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.logWeight, style: Theme.of(c).textTheme.titleLarge),
              StatefulBuilder(
                builder: (c, setState) => NumberWheel(
                  values: steppedValues(minWeightKg, maxWeightKg, 0.1),
                  value: value,
                  fractionDigits: 1,
                  onChanged: (v) => setState(() => value = v),
                ),
              ),
              Text(t.unitKg),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('weight-save'),
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(t.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await ref
          .read(progressRepositoryProvider)
          .setWeight(ref.read(todayProvider), (value * 10).round() / 10);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).value;
    final weights = ref.watch(weightsProvider).value ?? const <WeightLog>[];
    final current = weights.isEmpty ? null : weights.last.weightKg;
    final start = profile?.startWeightKg;
    final showGoal = profile != null && profile.goalType != GoalType.maintain;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.weightTitle, style: tt.titleMedium)),
                FilledButton.tonalIcon(
                  key: const Key('log-weight'),
                  onPressed: () =>
                      _logWeight(context, ref, current ?? start ?? 70),
                  icon: const Icon(Icons.add),
                  label: Text(t.logWeight),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Stat(t.weightStart, start == null ? t.noValue : t.kg(start)),
                _Stat(
                  t.weightCurrent,
                  current == null ? t.noValue : t.kg(current),
                  key: const Key('weight-current'),
                ),
                if (showGoal)
                  _Stat(t.weightGoalLabel, t.kg(profile.goalWeightKg)),
              ],
            ),
            if (start != null && current != null && current != start)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t.weightChangeFromStart(
                    formatPersianNumber(current - start, fractionDigits: 1),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 12),
            if (weights.length >= 2)
              SizedBox(
                height: 180,
                child: _WeightChart(
                  weights: weights,
                  goalKg: showGoal ? profile.goalWeightKg : null,
                ),
              )
            else if (weights.isEmpty)
              Text(t.noWeights, textAlign: TextAlign.center),
            for (final w in weights.reversed.take(5))
              ListTile(
                key: Key('weight-${w.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t.formatDateLong(parseDayKey(w.date))),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.kg(w.weightKg)),
                    IconButton(
                      tooltip: t.deleteItem,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            content: Text(t.deleteWeightConfirm),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: Text(t.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: Text(t.deleteItem),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref
                              .read(progressRepositoryProvider)
                              .deleteWeight(w.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// نمودار وزن با خط هدف (محور زمان چپ‌به‌راست، برچسب‌ها فارسی).
class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.weights, this.goalKg});

  final List<WeightLog> weights;
  final double? goalKg;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final first = parseDayKey(weights.first.date);
    final spots = [
      for (final w in weights)
        FlSpot(
          parseDayKey(w.date).difference(first).inDays.toDouble(),
          w.weightKg,
        ),
    ];
    final ys = [...spots.map((s) => s.y), ?goalKg];
    final lo = ys.reduce(math.min) - 1, hi = ys.reduce(math.max) + 1;
    final maxX = math.max(1.0, spots.last.x);
    final label = Theme.of(context).textTheme.bodySmall;
    return Directionality(
      textDirection: TextDirection.ltr,
      // فاصله تا برچسب آخرین تاریخ بریده نشود.
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
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
                  getTitlesWidget: (v, m) => SideTitleWidget(
                    meta: m,
                    child: Text(formatPersianNumber(v), style: label),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: math.max(1.0, (maxX / 3).ceilToDouble()),
                  getTitlesWidget: (v, m) => SideTitleWidget(
                    meta: m,
                    child: Text(
                      t
                          .formatDateLong(first.add(Duration(days: v.round())))
                          .split(' ')
                          .take(2)
                          .join(' '),
                      style: label,
                    ),
                  ),
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (goalKg != null)
                  HorizontalLine(
                    y: goalKg!,
                    color: BrandColors.orangeDeep,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                  ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                color: cs.primary,
                barWidth: 3,
                dotData: const FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- کالری ----

class _CaloriesCard extends ConsumerStatefulWidget {
  const _CaloriesCard();

  @override
  ConsumerState<_CaloriesCard> createState() => _CaloriesCardState();
}

class _CaloriesCardState extends ConsumerState<_CaloriesCard> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final totals = ref.watch(dailyTotalsProvider(_days)).value ?? const {};
    final goal = ref.watch(goalOnProvider(today)).value;
    final logged = totals.values.toList();
    double avg(double Function(DayTotals) f) => logged.isEmpty
        ? 0
        : logged.map(f).reduce((a, b) => a + b) / logged.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.caloriesTitle, style: tt.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 7, label: Text(t.range7)),
                ButtonSegment(value: 30, label: Text(t.range30)),
              ],
              selected: {_days},
              onSelectionChanged: (v) => setState(() => _days = v.first),
            ),
            const SizedBox(height: 12),
            if (logged.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(t.noLogsRange, textAlign: TextAlign.center),
              )
            else ...[
              SizedBox(
                height: 160,
                child: _CaloriesChart(
                  days: _days,
                  today: today,
                  totals: totals,
                  goal: goal?.kcal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.avgKcal(formatPersianNumber(avg((d) => d.kcal))),
                key: const Key('avg-kcal'),
              ),
              Text(
                t.avgMacros(
                  formatPersianNumber(avg((d) => d.protein)),
                  formatPersianNumber(avg((d) => d.carbs)),
                  formatPersianNumber(avg((d) => d.fat)),
                ),
                style: tt.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CaloriesChart extends StatelessWidget {
  const _CaloriesChart({
    required this.days,
    required this.today,
    required this.totals,
    this.goal,
  });

  final int days;
  final DateTime today;
  final Map<String, DayTotals> totals;
  final int? goal;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final label = Theme.of(context).textTheme.bodySmall;
    final dates = [
      for (var i = days - 1; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final values = [for (final d in dates) totals[dayKey(d)]?.kcal ?? 0];
    final maxY =
        math.max(values.fold<double>(0, math.max), (goal ?? 0).toDouble()) *
            1.15 +
        1;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  final step = days <= 7 ? 1 : 5;
                  if ((days - 1 - i) % step != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: m,
                    child: Text(
                      days <= 7
                          ? t.weekdayShort(dates[i])
                          : toPersianDigits('${jalaliDay(dates[i])}'),
                      style: label,
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (goal != null)
                HorizontalLine(
                  y: goal!.toDouble(),
                  color: BrandColors.orangeDeep,
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                ),
            ],
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: days <= 7 ? 18 : 6,
                    color: BrandColors.green,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---- نشان‌ها ----

class _BadgesCard extends ConsumerWidget {
  const _BadgesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final earned = ref.watch(badgesProvider);
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.badgesTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 8,
              runSpacing: 12,
              children: [
                for (final a in Achievement.values)
                  SizedBox(
                    width: 96,
                    child: Tooltip(
                      message: earned.contains(a)
                          ? t.achievementDesc(a)
                          : t.badgeLocked,
                      child: Column(
                        key: Key(
                          'badge-${a.name}-${earned.contains(a) ? 'on' : 'off'}',
                        ),
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: earned.contains(a)
                                ? BrandColors.orangeDeep
                                : cs.surfaceContainerHighest,
                            child: Icon(
                              achievementIcon(a),
                              color: earned.contains(a)
                                  ? Colors.white
                                  : cs.outline,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.achievementName(a),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: earned.contains(a) ? null : cs.outline,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- قبل و بعد ----

/// عکس قبل/بعد کمی باکیفیت‌تر از عکس غذا (در isolate جدا).
Uint8List? _compressProgressPhoto(Uint8List raw) =>
    compressForScan(raw, maxBytes: 400 * 1024);

class _BeforeAfterCard extends ConsumerWidget {
  const _BeforeAfterCard();

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref, {
    required bool before,
  }) async {
    final t = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ScanSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.actionCamera),
              onTap: () => Navigator.pop(c, ScanSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.actionGallery),
              onTap: () => Navigator.pop(c, ScanSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final raw = await ref.read(photoSourceProvider).pick(source);
    if (raw == null) return;
    final jpeg = await compute(_compressProgressPhoto, raw) ?? raw;
    final path = await ref.read(photoStoreProvider).save(jpeg);
    final weights = ref.read(weightsProvider).value ?? const <WeightLog>[];
    await ref
        .read(beforeAfterProvider.notifier)
        .set(
          before: before,
          photo: (
            path: path,
            date: ref.read(todayProvider),
            weightKg: weights.isEmpty ? null : weights.last.weightKg,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final ba =
        ref.watch(beforeAfterProvider).value ?? (before: null, after: null);
    final both = ba.before != null && ba.after != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.beforeAfterTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              t.beforeAfterPrivacy,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Slot(
                  key: const Key('photo-before'),
                  label: t.photoBefore,
                  photo: ba.before,
                  onTap: () => _pick(context, ref, before: true),
                ),
                const SizedBox(width: 12),
                _Slot(
                  key: const Key('photo-after'),
                  label: t.photoAfter,
                  photo: ba.after,
                  onTap: () => _pick(context, ref, before: false),
                ),
              ],
            ),
            if (both) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('share-before-after'),
                onPressed: () {
                  final b = ba.before!, a = ba.after!;
                  final change = b.weightKg != null && a.weightKg != null
                      ? a.weightKg! - b.weightKg!
                      : null;
                  showShareCardDialog(
                    context,
                    ShareCard.beforeAfter(
                      before: b.path,
                      after: a.path,
                      weightChangeKg: change == 0 ? null : change,
                      days: a.date.difference(b.date).inDays.abs(),
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: Text(t.shareCard),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    super.key,
    required this.label,
    required this.photo,
    required this.onTap,
  });

  final String label;
  final ProgressPhoto? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final p = photo;
    final exists = p != null && File(p.path).existsSync();
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: exists
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(p.path), fit: BoxFit.cover),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          color: Colors.black45,
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            '$label · ${t.formatDateLong(p.date)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: cs.outline),
                      const SizedBox(height: 4),
                      Text(label),
                      Text(t.addPhoto, style: TextStyle(color: cs.outline)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
