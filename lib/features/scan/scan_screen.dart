import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/nutrition/serving.dart';
import '../../core/recognition/food_recognizer.dart';
import '../../core/utils/jalali_date.dart';
import '../../core/utils/persian_digits.dart';
import '../../data/db/app_database.dart';
import '../../data/foods/food.dart';
import '../../data/foods/food_repository.dart';
import '../../data/scan/pending_scan_repository.dart';
import '../../l10n/app_localizations.dart';
import '../logging/logging_labels.dart';
import 'photo_source.dart';
import 'scan_service.dart';

/// اطمینان کمتر از این ← «مطمئن نیستیم، لطفاً بررسی کن».
const lowConfidence = 0.6;

const _guideSeenKey = 'scan_guide_seen';

enum _Phase { loading, guide, analyzing, result, notFood, failed, queued }

/// یک آیتم قابل ویرایش در صفحه‌ی نتیجه.
class ScanDraftItem {
  ScanDraftItem({
    required this.food,
    required this.detectedName,
    required this.quantity,
    required this.unit,
    required this.confidence,
    this.unitAdjusted = false,
  });

  Food? food;
  final String detectedName;
  double quantity;
  String unit;
  final double confidence;
  bool unitAdjusted;

  ({double? grams, Nutrients nutrients}) get serving => food == null
      ? (grams: null, nutrients: const Nutrients())
      : food!.serving(unit, quantity);
}

/// تبدیل خروجی تشخیص به آیتم‌های قابل ویرایش (کالری از پایگاه محلی).
List<ScanDraftItem> draftFrom(RecognitionResult r, FoodRepository foods) => [
  for (final i in r.items)
    () {
      final food = i.foodId == null ? null : foods.byId(i.foodId!);
      final known = food?.units.any((u) => u.unit == i.unit) ?? true;
      return ScanDraftItem(
        food: food,
        detectedName: i.nameFa,
        quantity: i.quantity,
        unit: known ? i.unit : food!.defaultUnit,
        confidence: i.confidence,
        unitAdjusted: !known,
      );
    }(),
];

/// جریان اسکن (بخش ۵-۲): راهنما ← عکس ← «در حال تحلیل…» ← نتیجه‌ی قابل ویرایش
/// ← ثبت در وعده. بدون اینترنت: صف آفلاین. با [pendingId]: بررسی نتیجه‌ی صف.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({
    super.key,
    this.source,
    this.meal,
    this.day,
    this.pendingId,
  });

  final ScanSource? source;
  final MealType? meal;
  final DateTime? day;
  final int? pendingId;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  _Phase _phase = _Phase.loading;
  Uint8List? _jpeg;
  RecognitionResult? _result;
  List<ScanDraftItem> _items = [];
  ApiErrorKind? _error;
  late MealType _meal = widget.meal ?? defaultMealForTime(DateTime.now());
  late DateTime _day = widget.day ?? ref.read<DateTime>(selectedDayProvider);
  PendingScan? _pending;
  int _tip = 0;
  Timer? _tipTimer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.pendingId != null) return _loadPending();
    final seen = await ref.read(databaseProvider).getSetting(_guideSeenKey);
    if (!mounted) return;
    if (widget.source == ScanSource.camera && seen == null) {
      setState(() => _phase = _Phase.guide);
    } else {
      await _pickAndAnalyze();
    }
  }

  Future<void> _loadPending() async {
    final p = await ref
        .read(pendingScanRepositoryProvider)
        .byId(widget.pendingId!);
    final result = p == null ? null : PendingScanRepository.resultOf(p);
    final bytes = p == null
        ? null
        : await ref.read(photoStoreProvider).read(p.photoPath);
    final foods = await ref.read(foodRepositoryProvider.future);
    if (!mounted) return;
    if (p == null || result == null) {
      context.go(Routes.today);
      return;
    }
    setState(() {
      _pending = p;
      _jpeg = bytes;
      _meal = p.mealType ?? _meal;
      _day = p.date == null ? _day : parseDayKey(p.date!);
      _show(result, foods);
    });
  }

  Future<void> _pickAndAnalyze() async {
    final source = widget.source ?? ScanSource.gallery;
    final raw = await ref.read(photoSourceProvider).pick(source);
    if (!mounted) return;
    if (raw == null) {
      // انصراف از دوربین/گالری.
      if (_phase == _Phase.loading || _phase == _Phase.guide) context.pop();
      return;
    }
    setState(() {
      _phase = _Phase.analyzing;
      // عکس خام فوراً نمایش داده می‌شود؛ نسخه‌ی فشرده بعداً جایگزین می‌شود.
      _jpeg = raw;
    });
    _startTips();
    final jpeg = await ref.read(scanServiceProvider).prepare(raw);
    if (!mounted) return;
    if (jpeg == null) {
      return setState(() {
        _phase = _Phase.failed;
        _error = ApiErrorKind.badImage;
      });
    }
    setState(() => _jpeg = jpeg);
    await _analyze();
  }

  Future<void> _analyze() async {
    setState(() => _phase = _Phase.analyzing);
    _startTips();
    final outcome = await ref
        .read(scanServiceProvider)
        .analyze(_jpeg!, meal: _meal, dayKey: dayKey(_day));
    final foods = await ref.read(foodRepositoryProvider.future);
    _tipTimer?.cancel();
    if (!mounted) return;
    setState(() {
      switch (outcome) {
        case ScanSucceeded(:final result):
          _show(result, foods);
        case ScanQueued():
          _phase = _Phase.queued;
        case ScanFailed(:final kind):
          _phase = _Phase.failed;
          _error = kind;
        case ScanBadImage():
          _phase = _Phase.failed;
          _error = ApiErrorKind.badImage;
      }
    });
  }

  void _show(RecognitionResult result, FoodRepository foods) {
    _result = result;
    if (!result.isFood) {
      _phase = _Phase.notFood;
      return;
    }
    _items = draftFrom(result, foods);
    _phase = _Phase.result;
  }

  void _startTips() {
    _tipTimer?.cancel();
    _tipTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _tip++);
    });
  }

  Future<Food?> _pickFood() => context.push<Food>(Routes.pickFood);

  Future<void> _save() async {
    setState(() => _saving = true);
    final photos = ref.read(photoStoreProvider);
    final logs = ref.read(foodLogRepositoryProvider);
    final photoPath =
        _pending?.photoPath ??
        (_jpeg == null ? null : await photos.save(_jpeg!));
    for (final i in _items) {
      final s = i.serving;
      await logs.add(
        dayKey: dayKey(_day),
        meal: _meal,
        foodId: i.food?.id,
        customName: i.food == null ? i.detectedName : null,
        quantity: i.quantity,
        unit: i.unit,
        grams: s.grams,
        nutrients: s.nutrients,
        source: LogSource.photo,
        photoPath: photoPath,
        scanId: _result?.scanId,
      );
    }
    if (_pending != null) {
      await ref.read(pendingScanRepositoryProvider).delete(_pending!.id);
    }
    if (!mounted) return;
    ref.read(selectedDayProvider.notifier).select(_day);
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.logged)));
    context.go(Routes.today);
  }

  Future<void> _discardPending() async {
    final p = _pending!;
    await ref.read(pendingScanRepositoryProvider).delete(p.id);
    await ref.read(photoStoreProvider).delete(p.photoPath);
    if (mounted) context.go(Routes.today);
  }

  void _manualLog() =>
      context.pushReplacement(Routes.searchFor(meal: _meal, day: _day));

  Future<void> _markGuideSeen() async {
    await ref.read(databaseProvider).setSetting(_guideSeenKey, '1');
    await _pickAndAnalyze();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _phase == _Phase.result ? t.scanResultTitle : t.actionCamera,
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.guide => _guide(t),
          _Phase.analyzing => _analyzing(t),
          _Phase.result => _resultView(t),
          _Phase.notFood => _message(
            t,
            icon: Icons.no_food_outlined,
            title: t.scanNotFood,
            body: t.scanNotFoodHint,
            primary: _pending == null
                ? (t.takeAnother, _pickAndAnalyze)
                : (t.discard, _discardPending),
          ),
          _Phase.queued => _message(
            t,
            icon: Icons.cloud_off_outlined,
            title: t.scanOfflineTitle,
            body: t.scanOfflineQueued,
            primary: (t.manualLog, _manualLog),
          ),
          _Phase.failed => _failed(t),
        },
      ),
      bottomNavigationBar: _phase == _Phase.result
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  key: const Key('scan-save'),
                  onPressed: _saving || _items.isEmpty ? null : _save,
                  child: Text(t.logToMeal(t.mealLabel(_meal))),
                ),
              ),
            )
          : null,
    );
  }

  // ---- راهنمای کادر (فقط بار اول) ----

  Widget _guide(AppLocalizations t) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.dinner_dining,
            size: 120,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(t.scanGuideTitle, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      for (final line in [t.scanGuide1, t.scanGuide2, t.scanGuide3])
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_circle_outline),
          title: Text(line),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('scan-guide-ok'),
        onPressed: _markGuideSeen,
        icon: const Icon(Icons.photo_camera),
        label: Text(t.scanGuideOk),
      ),
    ],
  );

  // ---- در حال تحلیل ----

  Widget _analyzing(AppLocalizations t) {
    final tips = [t.scanTip1, t.scanTip2, t.scanTip3, t.scanTip4, t.scanTip5];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_jpeg != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(_jpeg!, height: 220, fit: BoxFit.cover),
            )
          else
            const SizedBox(height: 220),
          const SizedBox(height: 24),
          Text(t.analyzing, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              tips[_tip % tips.length],
              key: ValueKey(_tip % tips.length),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  // ---- نتیجه‌ی قابل ویرایش ----

  Widget _resultView(AppLocalizations t) {
    final tt = Theme.of(context).textTheme;
    final anyLow = _items.any(
      (i) => i.confidence < lowConfidence || i.food == null,
    );
    final total = DayTotals.sum(_items.map((i) => i.serving.nutrients));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_jpeg != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(_jpeg!, height: 180, fit: BoxFit.cover),
          ),
        if (_result?.notesFa != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_result!.notesFa!, style: tt.bodySmall),
          ),
        if (anyLow)
          Card(
            key: const Key('scan-low-confidence'),
            color: BrandColors.orange.withValues(alpha: 0.18),
            margin: const EdgeInsets.only(top: 12),
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(t.scanLowConfidence),
            ),
          ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t.scanNoItems, textAlign: TextAlign.center),
          ),
        for (var i = 0; i < _items.length; i++) _itemCard(t, i),
        TextButton.icon(
          key: const Key('scan-add-missing'),
          onPressed: () async {
            final f = await _pickFood();
            if (f == null) return;
            setState(
              () => _items.add(
                ScanDraftItem(
                  food: f,
                  detectedName: f.nameFa,
                  quantity: 1,
                  unit: f.defaultUnit,
                  confidence: 1,
                ),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: Text(t.scanAddMissing),
        ),
        const SizedBox(height: 8),
        Text(
          '${t.kcalUnit}: ${t.kcalOrDash(_items.any((i) => i.serving.nutrients.kcal != null) ? total.kcal : null)}',
          key: const Key('scan-total'),
          style: tt.titleMedium,
        ),
        if (total.incompleteCount > 0)
          Text(
            t.incompleteItems(toPersianDigits('${total.incompleteCount}')),
            style: tt.bodySmall,
          ),
        const SizedBox(height: 16),
        Text(t.meal, style: tt.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<MealType>(
          showSelectedIcon: false,
          segments: [
            for (final m in MealType.values)
              ButtonSegment(value: m, label: Text(t.mealLabel(m))),
          ],
          selected: {_meal},
          onSelectionChanged: (v) => setState(() => _meal = v.first),
        ),
        if (_pending != null)
          TextButton(onPressed: _discardPending, child: Text(t.discard)),
      ],
    );
  }

  Widget _itemCard(AppLocalizations t, int index) {
    final item = _items[index];
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final food = item.food;
    final step = item.unit == 'gram' ? 10.0 : 0.5;
    final unitName = food?.unitOf(item.unit).nameFa;
    final s = item.serving;

    Future<void> changeFood() async {
      final f = await _pickFood();
      if (f == null) return;
      setState(() {
        item.food = f;
        if (!f.units.any((u) => u.unit == item.unit)) {
          item.unit = f.defaultUnit;
        }
        item.unitAdjusted = false;
      });
    }

    Future<void> chooseUnit() async {
      if (food == null) return;
      final u = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final fu in food.units)
                ChoiceChip(
                  label: Text(t.unitLabel(fu.unit, fallback: fu.nameFa)),
                  selected: fu.unit == item.unit,
                  onSelected: (_) => Navigator.pop(c, fu.unit),
                ),
            ],
          ),
        ),
      );
      if (u != null && u != item.unit) {
        setState(() {
          item.unit = u;
          item.quantity = u == 'gram' ? 100 : 1;
          item.unitAdjusted = false;
        });
      }
    }

    return Card(
      key: Key('scan-item-$index'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (item.confidence < lowConfidence)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Icon(Icons.warning_amber, size: 20, color: cs.error),
                  ),
                Expanded(
                  child: Text(
                    food?.nameFa ?? item.detectedName,
                    style: tt.titleMedium,
                  ),
                ),
                Text(
                  t.confidenceValue(
                    toPersianDigits('${(item.confidence * 100).round()}'),
                  ),
                  style: tt.bodySmall,
                ),
                IconButton(
                  key: Key('scan-item-delete-$index'),
                  tooltip: t.deleteItem,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
              ],
            ),
            if (food == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: OutlinedButton.icon(
                  key: Key('scan-item-choose-$index'),
                  onPressed: changeFood,
                  icon: const Icon(Icons.search),
                  label: Text(t.scanNotFound),
                ),
              )
            else ...[
              if (food.nameFa != item.detectedName)
                Text(t.scanDetected(item.detectedName), style: tt.bodySmall),
              Row(
                children: [
                  IconButton(
                    key: Key('scan-item-minus-$index'),
                    tooltip: t.decrease,
                    onPressed: item.quantity - step > 0
                        ? () => setState(() => item.quantity -= step)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Flexible(
                    child: InkWell(
                      onTap: chooseUnit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          t.quantityLabel(
                            item.quantity,
                            item.unit,
                            fallback: unitName,
                          ),
                          key: Key('scan-item-qty-$index'),
                          style: tt.titleMedium,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('scan-item-plus-$index'),
                    tooltip: t.increase,
                    onPressed: () => setState(() => item.quantity += step),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const Spacer(),
                  if (s.nutrients.kcal == null)
                    Text(t.dataIncomplete, style: tt.bodySmall)
                  else
                    Text(t.kcalOrDash(s.nutrients.kcal)),
                  const SizedBox(width: 8),
                ],
              ),
              if (item.unitAdjusted)
                Text(
                  t.scanUnitAdjusted(
                    t.unitLabel(item.unit, fallback: unitName),
                  ),
                  style: tt.bodySmall,
                ),
              TextButton(onPressed: changeFood, child: Text(t.scanChangeFood)),
            ],
          ],
        ),
      ),
    );
  }

  // ---- خطاها ----

  Widget _failed(AppLocalizations t) {
    if (_error == ApiErrorKind.quotaExceeded) {
      return _message(
        t,
        icon: Icons.hourglass_empty,
        title: t.scanQuotaTitle,
        body: t.scanQuotaHint,
        primary: (t.manualLog, _manualLog),
        // ویدیوی جایزه‌دار و اشتراک در مرحله‌ی ۵.
        extra: [
          OutlinedButton(
            onPressed: null,
            child: Text('${t.scanQuotaVideo} (${t.comingSoon})'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: null,
            child: Text('${t.scanQuotaPremium} (${t.comingSoon})'),
          ),
        ],
      );
    }
    final (msg, canRetry) = switch (_error) {
      ApiErrorKind.timeout => (t.scanTimeout, true),
      ApiErrorKind.busy => (t.scanBusy, true),
      ApiErrorKind.rateLimited => (t.scanRateLimited, true),
      ApiErrorKind.badImage => (t.scanBadImage, false),
      _ => (t.scanError, true),
    };
    return _message(
      t,
      icon: Icons.error_outline,
      title: msg,
      primary: canRetry && _jpeg != null
          ? (t.retry, _analyze)
          : (t.takeAnother, _pickAndAnalyze),
      secondary: (t.manualLog, _manualLog),
    );
  }

  Widget _message(
    AppLocalizations t, {
    required IconData icon,
    required String title,
    String? body,
    required (String, VoidCallback) primary,
    (String, VoidCallback)? secondary,
    List<Widget> extra = const [],
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            key: const Key('scan-message'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('scan-primary'),
            onPressed: primary.$2,
            child: Text(primary.$1),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('scan-secondary'),
              onPressed: secondary.$2,
              child: Text(secondary.$1),
            ),
          ],
          if (extra.isNotEmpty) ...[const SizedBox(height: 16), ...extra],
        ],
      ),
    ),
  );
}
