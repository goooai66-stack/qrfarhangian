import 'dart:io';

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
    this.ramadan = false,
    this.onSaveCustom,
    this.onCopyYesterday,
  });

  final MealType meal;
  final List<FoodLog> logs;
  final Food? Function(String? id) foodOf;
  final VoidCallback onAdd;
  final ValueChanged<FoodLog> onTapItem;
  final bool ramadan;

  /// «ذخیره به‌عنوان غذای ترکیبی» (اگر null، گزینه نیست).
  final VoidCallback? onSaveCustom;
  final VoidCallback? onCopyYesterday;

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
                Text(
                  t.mealLabel(meal, ramadan: ramadan),
                  style: tt.titleMedium,
                ),
                const SizedBox(width: 8),
                if (logs.isNotEmpty)
                  Text(
                    t.kcalValue(formatPersianNumber(total)),
                    style: tt.bodyMedium?.copyWith(color: cs.primary),
                  ),
                const Spacer(),
                if (onSaveCustom != null || onCopyYesterday != null)
                  PopupMenuButton<int>(
                    key: Key('meal-menu-${meal.name}'),
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) =>
                        (v == 0 ? onSaveCustom : onCopyYesterday)?.call(),
                    itemBuilder: (_) => [
                      if (onSaveCustom != null)
                        PopupMenuItem(
                          value: 0,
                          child: Text(t.saveAsCustomMeal),
                        ),
                      if (onCopyYesterday != null)
                        PopupMenuItem(value: 1, child: Text(t.copyYesterday)),
                    ],
                  ),
                IconButton(
                  key: Key('add-${meal.name}'),
                  tooltip: t.addToMeal(t.mealLabel(meal, ramadan: ramadan)),
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
      leading: _Thumb(path: l.photoPath),
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

/// عکس کوچک ثبت‌های عکسی؛ اگر عکسی نیست یا پاک شده، آیکون.
class _Thumb extends StatelessWidget {
  const _Thumb({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p != null && File(p).existsSync()) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: ResizeImage(FileImage(File(p)), width: 96),
      );
    }
    return const CircleAvatar(
      radius: 18,
      child: Icon(Icons.restaurant, size: 18),
    );
  }
}
