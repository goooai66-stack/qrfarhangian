import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/ads/ad_service.dart';
import '../../core/utils/jalali_date.dart';
import '../../core/utils/persian_digits.dart';
import '../../data/db/app_database.dart';
import '../../data/foods/food.dart';
import '../../data/logs/custom_meal_repository.dart';
import '../../core/analytics/analytics.dart';
import 'logging_labels.dart';
import '../monetization/ad_coordinator.dart';
import '../../data/foods/food_repository.dart';
import '../../l10n/app_localizations.dart';

/// جستجوی غذا. بدون عبارت: علاقه‌مندی‌ها، اخیر، پرتکرار و همه‌ی غذاها
/// (ثبت یک غذای اخیر: «ثبت غذا» ← غذا ← «ثبت» = ۳ لمس).
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({
    super.key,
    this.meal,
    this.day,
    this.pickMode = false,
  });

  final MealType? meal;
  final DateTime? day;

  /// حالت انتخاب: با لمس غذا، همان [Food] برمی‌گردد (برای صفحه‌ی نتیجه‌ی اسکن).
  final bool pickMode;

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(Food f) {
    if (widget.pickMode) {
      context.pop(f);
      return;
    }
    final meal =
        widget.meal ??
        defaultMealForTime(DateTime.now(), ramadan: ref.read(ramadanProvider));
    final day = widget.day ?? ref.read<DateTime>(selectedDayProvider);
    context.push(Routes.foodFor(foodId: f.id, meal: meal, day: day));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repo = ref.watch(foodRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('search-field'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: t.searchHint,
            border: InputBorder.none,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      // بنر فقط اینجا (بخش ۹-۲).
      bottomNavigationBar: widget.pickMode
          ? null
          : const SafeArea(child: AdSlot(AdPlacement.bannerSearch)),
      body: repo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (r) => _query.trim().isEmpty ? _browse(t, r) : _results(t, r),
      ),
    );
  }

  Widget _results(AppLocalizations t, FoodRepository repo) {
    final freq = ref.watch(foodFrequencyProvider).value ?? const {};
    final favs = ref.watch(favoriteFoodIdsProvider).value ?? const {};
    final found = repo.search(_query, frequency: freq);
    if (found.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.searchNoResult, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      children: [for (final f in found) _tile(t, f, favs.contains(f.id))],
    );
  }

  Widget _browse(AppLocalizations t, FoodRepository repo) {
    final freq = ref.watch(foodFrequencyProvider).value ?? const {};
    final favs = ref.watch(favoriteFoodIdsProvider).value ?? const {};
    final recent = ref.watch(recentFoodIdsProvider).value ?? const [];

    List<Food> resolve(Iterable<String> ids) => [
      for (final id in ids) ?repo.byId(id),
    ];
    final favFoods = resolve(favs)
      ..sort((a, b) => a.nameFa.compareTo(b.nameFa));
    final recentFoods = resolve(recent);
    final frequent = resolve(
      (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .where((e) => !recent.contains(e.key))
          .take(5)
          .map((e) => e.key),
    );
    final all = [...repo.foods]
      ..sort((a, b) {
        final c = (freq[b.id] ?? 0).compareTo(freq[a.id] ?? 0);
        return c != 0 ? c : a.nameFa.compareTo(b.nameFa);
      });

    final customMeals = widget.pickMode
        ? const <CustomMeal>[]
        : ref.watch(customMealsProvider).value ?? const <CustomMeal>[];

    return ListView(
      children: [
        if (customMeals.isNotEmpty) ...[
          _header(t.customMeals),
          for (final m in customMeals) _customTile(t, m),
        ],
        if (favFoods.isNotEmpty) ...[
          _header(t.sectionFavorites),
          for (final f in favFoods) _tile(t, f, true),
        ],
        if (recentFoods.isNotEmpty) ...[
          _header(t.sectionRecent),
          for (final f in recentFoods) _tile(t, f, favs.contains(f.id)),
        ],
        if (frequent.isNotEmpty) ...[
          _header(t.sectionFrequent),
          for (final f in frequent) _tile(t, f, favs.contains(f.id)),
        ],
        _header(t.sectionAll),
        for (final f in all) _tile(t, f, favs.contains(f.id)),
      ],
    );
  }

  Widget _customTile(AppLocalizations t, CustomMeal m) {
    final n = CustomMealRepository.itemsOf(m).length;
    return ListTile(
      key: Key('custom-${m.id}'),
      leading: const Icon(Icons.bookmark_outline),
      title: Text(m.name),
      subtitle: Text(t.customMealItems(toPersianDigits('$n'))),
      onTap: () => _logCustom(t, m),
      onLongPress: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            content: Text(t.customMealDeleteConfirm(m.name)),
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
          await ref.read(customMealRepositoryProvider).delete(m.id);
        }
      },
    );
  }

  /// ثبت همه‌ی اقلام غذای ترکیبی در وعده (با تأیید).
  Future<void> _logCustom(AppLocalizations t, CustomMeal m) async {
    final ramadan = ref.read(ramadanProvider);
    final meal =
        widget.meal ?? defaultMealForTime(DateTime.now(), ramadan: ramadan);
    final day = widget.day ?? ref.read<DateTime>(selectedDayProvider);
    final foods = await ref.read(foodRepositoryProvider.future);
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(m.name, style: Theme.of(c).textTheme.titleLarge),
              for (final i in CustomMealRepository.itemsOf(m))
                ListTile(
                  dense: true,
                  title: Text(foods.byId(i.foodId)?.nameFa ?? t.unknownFood),
                  trailing: Text(t.quantityLabel(i.quantity, i.unit)),
                ),
              FilledButton(
                key: const Key('custom-log'),
                onPressed: () => Navigator.pop(c, true),
                child: Text(t.logToMeal(t.mealLabel(meal, ramadan: ramadan))),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final n = await ref
        .read(customMealRepositoryProvider)
        .logToMeal(
          m,
          foods: foods,
          logs: ref.read(foodLogRepositoryProvider),
          dayKey: dayKey(day),
          mealType: meal,
        );
    ref.read(selectedDayProvider.notifier).select(day);
    await ref.read(analyticsProvider).track(AnalyticsEvent.logFood);
    await ref.read(adCoordinatorProvider).afterLogSaved();
    messenger.showSnackBar(
      SnackBar(content: Text(t.customMealLogged(toPersianDigits('$n')))),
    );
    if (mounted) context.go(Routes.today);
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );

  Widget _tile(AppLocalizations t, Food f, bool favorite) => ListTile(
    key: Key('food-${f.id}'),
    title: Text(f.nameFa),
    subtitle: f.aliases.isEmpty ? null : Text(f.aliases.take(2).join('، ')),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!f.hasNutrition)
          Text(
            t.dataIncomplete,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          )
        else if (!f.verified)
          Text(t.dataApprox, style: Theme.of(context).textTheme.bodySmall),
        if (favorite) ...[
          const SizedBox(width: 8),
          const Icon(Icons.star, size: 18, color: Colors.amber),
        ],
      ],
    ),
    onTap: () => _open(f),
  );
}
