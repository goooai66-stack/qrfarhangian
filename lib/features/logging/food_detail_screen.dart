import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/nutrition/serving.dart';
import '../../core/utils/jalali_date.dart';
import '../../core/utils/persian_digits.dart';
import '../../data/db/app_database.dart';
import '../../data/foods/food.dart';
import '../../l10n/app_localizations.dart';
import 'logging_labels.dart';

/// جزئیات غذا: واحد و مقدار ← محاسبه‌ی زنده؛ ثبت در وعده یا ویرایش ثبت قبلی.
class FoodDetailScreen extends ConsumerStatefulWidget {
  const FoodDetailScreen({
    super.key,
    required this.foodId,
    this.meal,
    this.day,
    this.logId,
  });

  final String foodId;
  final MealType? meal;
  final DateTime? day;

  /// اگر داده شود، حالت ویرایش.
  final int? logId;

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  String? _unit;
  double _quantity = 1;
  late MealType _meal = widget.meal ?? defaultMealForTime(DateTime.now());
  FoodLog? _log;
  bool _loadingLog = false;
  bool _saving = false;

  bool get _editing => widget.logId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _loadLog();
  }

  Future<void> _loadLog() async {
    setState(() => _loadingLog = true);
    final l = await ref.read(foodLogRepositoryProvider).byId(widget.logId!);
    if (!mounted) return;
    setState(() {
      _log = l;
      _loadingLog = false;
      if (l != null) {
        _unit = l.unit;
        _quantity = l.quantity;
        _meal = l.mealType;
      }
    });
  }

  double _step(String unit) => unit == 'gram' ? 10 : 0.5;

  Future<void> _save(Food food) async {
    final unit = _unit ?? food.defaultUnit;
    final s = food.serving(unit, _quantity);
    final repo = ref.read(foodLogRepositoryProvider);
    setState(() => _saving = true);
    if (_editing) {
      await repo.updateServing(
        widget.logId!,
        meal: _meal,
        quantity: _quantity,
        unit: unit,
        grams: s.grams,
        nutrients: s.nutrients,
      );
    } else {
      final day = widget.day ?? ref.read<DateTime>(selectedDayProvider);
      await repo.add(
        dayKey: dayKey(day),
        meal: _meal,
        foodId: food.id,
        quantity: _quantity,
        unit: unit,
        grams: s.grams,
        nutrients: s.nutrients,
      );
      ref.read(selectedDayProvider.notifier).select(day);
    }
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_editing ? t.saved : t.logged)));
    context.go(Routes.today);
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(t.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t.cancel),
          ),
          TextButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.deleteItem),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(foodLogRepositoryProvider).delete(widget.logId!);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.deleted)));
    context.go(Routes.today);
  }

  Future<void> _typeQuantity() async {
    final t = AppLocalizations.of(context);
    final c = TextEditingController(
      text: formatPersianNumber(_quantity, fractionDigits: 2, grouping: false),
    );
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.enterQuantity),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, parsePersianNumber(c.text)?.toDouble()),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    if (v != null && v > 0 && v <= 10000) setState(() => _quantity = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = ref.watch(foodRepositoryProvider).value;
    final food = repo?.byId(widget.foodId);
    if (repo == null || _loadingLog) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (food == null || (_editing && _log == null)) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(t.foodNotFound)),
      );
    }

    final unit = _unit ?? food.defaultUnit;
    final fu = food.unitOf(unit);
    final s = food.serving(unit, _quantity);
    final favs = ref.watch(favoriteFoodIdsProvider).value ?? const {};
    final isFav = favs.contains(food.id);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(food.nameFa),
        actions: [
          IconButton(
            key: const Key('favorite'),
            tooltip: isFav ? t.favoriteRemove : t.favoriteAdd,
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : null,
            ),
            onPressed: () => ref
                .read(foodLogRepositoryProvider)
                .setFavorite(food.id, !isFav),
          ),
          if (_editing)
            IconButton(
              key: const Key('delete-log'),
              tooltip: t.deleteItem,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!food.hasNutrition)
            Card(
              color: cs.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(t.dataIncomplete),
                subtitle: Text(t.dataIncompleteHint),
              ),
            )
          else if (!food.verified)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip(label: Text(t.dataApprox)),
            ),
          const SizedBox(height: 8),
          Text(t.unit, style: tt.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final u in food.units)
                ChoiceChip(
                  key: Key('unit-${u.unit}'),
                  label: Text(t.unitLabel(u.unit, fallback: u.nameFa)),
                  selected: u.unit == unit,
                  onSelected: (_) => setState(() {
                    _unit = u.unit;
                    // مقدار پیش‌فرض منطقی برای هر نوع واحد.
                    _quantity = u.unit == 'gram' ? 100 : 1;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(t.quantity, style: tt.titleMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                key: const Key('qty-minus'),
                tooltip: t.decrease,
                iconSize: 32,
                onPressed: _quantity - _step(unit) > 0
                    ? () => setState(() => _quantity -= _step(unit))
                    : null,
                icon: const Icon(Icons.remove),
              ),
              // برچسب بلند (مثل «۱٫۵ قاشق غذاخوری») کوچک می‌شود، نه سرریز.
              Flexible(
                child: InkWell(
                  onTap: _typeQuantity,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        t.quantityLabel(_quantity, unit, fallback: fu.nameFa),
                        key: const Key('qty-label'),
                        style: tt.headlineSmall,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                key: const Key('qty-plus'),
                tooltip: t.increase,
                iconSize: 32,
                onPressed: () => setState(() => _quantity += _step(unit)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (fu.grams == null && food.hasNutrition)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t.unitWeightUnknown, style: tt.bodySmall),
            ),
          const SizedBox(height: 16),
          _NutrientsCard(nutrients: s.nutrients),
          const SizedBox(height: 20),
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            key: const Key('save-log'),
            onPressed: _saving ? null : () => _save(food),
            child: Text(_editing ? t.save : t.logToMeal(t.mealLabel(_meal))),
          ),
        ),
      ),
    );
  }
}

class _NutrientsCard extends StatelessWidget {
  const _NutrientsCard({required this.nutrients});

  final Nutrients nutrients;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    String g(double? v) =>
        v == null ? t.noValue : t.gramsValue(formatPersianNumber(v));
    Widget cell(String label, String value, {Key? key}) => Expanded(
      child: Column(
        children: [
          Text(label, style: tt.bodyMedium),
          Text(
            value,
            key: key,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            cell(
              t.kcalUnit,
              nutrients.kcal == null
                  ? t.noValue
                  : formatPersianNumber(nutrients.kcal!),
              key: const Key('detail-kcal'),
            ),
            cell(t.macroProtein, g(nutrients.protein)),
            cell(t.macroCarbs, g(nutrients.carbs)),
            cell(t.macroFat, g(nutrients.fat)),
          ],
        ),
      ),
    );
  }
}
