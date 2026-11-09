import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/nutrition/nutrition_types.dart';
import '../../data/foods/food.dart';
import '../../data/foods/food_repository.dart';
import '../../l10n/app_localizations.dart';

/// جستجوی غذا. بدون عبارت: علاقه‌مندی‌ها، اخیر، پرتکرار و همه‌ی غذاها
/// (ثبت یک غذای اخیر: «ثبت غذا» ← غذا ← «ثبت» = ۳ لمس).
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key, this.meal, this.day});

  final MealType? meal;
  final DateTime? day;

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
    final meal = widget.meal ?? defaultMealForTime(DateTime.now());
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

    return ListView(
      children: [
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
