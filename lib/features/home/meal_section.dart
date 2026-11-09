import 'package:flutter/material.dart';

import '../../core/utils/persian_digits.dart';
import '../../data/db/app_database.dart';
import '../../data/foods/food.dart';
import '../../l10n/app_localizations.dart';
import '../logging/logging_labels.dart';

/// یک وعده در داشبورد: عنوان، جمع کالری، آیتم‌ها و دکمه‌ی افزودن.
class MealSection extends StatelessWidget {
  const MealSection({
    super.key,
    required this.meal,
    required this.logs,
    required this.foodOf,
    required this.onAdd,
    required this.onTapItem,
  });

  final MealType meal;
  final List<FoodLog> logs;
  final Food? Function(String? id) foodOf;
  final VoidCallback onAdd;
  final ValueChanged<FoodLog> onTapItem;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final known = logs.where((l) => l.kcal != null);
    final total = known.fold<double>(0, (s, l) => s + l.kcal!);

    return Card(
      key: Key('meal-${meal.name}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Column(
          children: [
            Row(
              children: [
                Text(t.mealLabel(meal), style: tt.titleMedium),
                const SizedBox(width: 8),
                if (logs.isNotEmpty)
                  Text(
                    t.kcalValue(formatPersianNumber(total)),
                    style: tt.bodyMedium?.copyWith(color: cs.primary),
                  ),
                const Spacer(),
                IconButton(
                  key: Key('add-${meal.name}'),
                  tooltip: t.addToMeal(t.mealLabel(meal)),
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onAdd,
                ),
              ],
            ),
            if (logs.isEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    t.mealEmpty,
                    style: tt.bodySmall?.copyWith(color: cs.outline),
                  ),
                ),
              ),
            for (final l in logs) _item(context, t, l),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, AppLocalizations t, FoodLog l) {
    final food = foodOf(l.foodId);
    final unitName = food?.units
        .where((u) => u.unit == l.unit)
        .firstOrNull
        ?.nameFa;
    return ListTile(
      key: Key('log-${l.id}'),
      contentPadding: const EdgeInsetsDirectional.only(end: 12),
      dense: true,
      // جای عکس کوچک برای ثبت‌های عکسی (مرحله‌ی ۳).
      leading: const CircleAvatar(
        radius: 18,
        child: Icon(Icons.restaurant, size: 18),
      ),
      title: Text(food?.nameFa ?? l.customName ?? t.unknownFood),
      subtitle: Text(t.quantityLabel(l.quantity, l.unit, fallback: unitName)),
      trailing: l.kcal == null
          ? Chip(
              label: Text(t.dataIncomplete),
              visualDensity: VisualDensity.compact,
            )
          : Text(t.kcalOrDash(l.kcal)),
      onTap: () => onTapItem(l),
    );
  }
}
