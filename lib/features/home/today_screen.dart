import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/nutrition/serving.dart';
import '../../core/utils/jalali_date.dart';
import '../../core/utils/persian_digits.dart';
import '../../data/db/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../logging/log_food_sheet.dart';
import 'calorie_ring.dart';
import 'date_strip.dart';
import 'macro_bars.dart';
import 'meal_section.dart';
import 'water_card.dart';
import '../../l10n/date_names.dart';

/// تب «امروز»: داشبورد روزانه (بخش ۴-۳).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final day = ref.watch(selectedDayProvider);
    final today = dateOnly(DateTime.now());
    final logs = ref.watch(dayLogsProvider(day)).value ?? const <FoodLog>[];
    final goal = ref.watch(goalOnProvider(day)).value;
    final water = ref.watch(waterProvider(day)).value ?? 0;
    final foods = ref.watch(foodRepositoryProvider).value;
    final totals = DayTotals.sum([
      for (final l in logs)
        Nutrients(kcal: l.kcal, protein: l.protein, carbs: l.carbs, fat: l.fat),
    ]);
    final over = goal == null ? 0 : totals.kcal.round() - goal.kcal;

    // «+» هر وعده مستقیم جستجو را باز می‌کند (ثبت با جستجو = ۳ لمس).
    void openSearch(MealType meal) =>
        context.push(Routes.searchFor(meal: meal, day: day));

    void openLog(FoodLog l) {
      final food = l.foodId == null ? null : foods?.byId(l.foodId!);
      if (food != null) {
        context.push(Routes.editLog(foodId: food.id, logId: l.id));
      } else {
        _confirmDelete(context, ref, l);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          day == today ? t.tabToday : t.formatDateWithWeekday(day),
          key: const Key('today-title'),
        ),
        actions: [
          if (day != today)
            TextButton(
              onPressed: () => ref.read(selectedDayProvider.notifier).today(),
              child: Text(t.goToToday),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        children: [
          DateStrip(
            selected: day,
            today: today,
            onSelect: ref.read(selectedDayProvider.notifier).select,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CalorieRing(consumed: totals.kcal, goal: goal?.kcal),
                  const SizedBox(height: 8),
                  Text(
                    goal == null
                        ? t.noGoal
                        : '${t.kcalConsumed} ${formatPersianNumber(totals.kcal)}'
                              ' · ${t.kcalGoal} ${formatPersianNumber(goal.kcal)}',
                  ),
                  if (over > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        t.kcalOver(formatPersianNumber(over)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (totals.incompleteCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        t.incompleteItems(
                          toPersianDigits('${totals.incompleteCount}'),
                        ),
                        key: const Key('incomplete-note'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 16),
                  MacroBars(
                    protein: totals.protein,
                    carbs: totals.carbs,
                    fat: totals.fat,
                    proteinGoal: goal?.proteinG,
                    carbsGoal: goal?.carbsG,
                    fatGoal: goal?.fatG,
                  ),
                ],
              ),
            ),
          ),
          WaterCard(
            glasses: water,
            onChanged: (n) =>
                ref.read(foodLogRepositoryProvider).setWater(dayKey(day), n),
          ),
          for (final m in MealType.values)
            MealSection(
              meal: m,
              logs: [
                for (final l in logs)
                  if (l.mealType == m) l,
              ],
              foodOf: (id) => id == null ? null : foods?.byId(id),
              onAdd: () => openSearch(m),
              onTapItem: openLog,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('fab-log'),
        onPressed: () => showLogFoodSheet(
          context,
          meal: day == today
              ? defaultMealForTime(DateTime.now())
              : MealType.lunch,
          day: day,
        ),
        icon: const Icon(Icons.add),
        label: Text(t.logFood),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FoodLog l,
  ) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text('${t.foodNotFound}\n${t.deleteConfirm}'),
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
    if (ok == true) await ref.read(foodLogRepositoryProvider).delete(l.id);
  }
}
