import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';

/// سه نوار درشت‌مغذی: مصرف‌شده / هدف (گرم).
class MacroBars extends StatelessWidget {
  const MacroBars({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.proteinGoal,
    this.carbsGoal,
    this.fatGoal,
  });

  final double protein, carbs, fat;
  final double? proteinGoal, carbsGoal, fatGoal;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        _Bar(t.macroProtein, protein, proteinGoal, BrandColors.green),
        const SizedBox(width: 12),
        _Bar(t.macroCarbs, carbs, carbsGoal, BrandColors.orange),
        const SizedBox(width: 12),
        _Bar(t.macroFat, fat, fatGoal, Theme.of(context).colorScheme.tertiary),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value, this.goal, this.color);

  final String label;
  final double value;
  final double? goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final g = goal;
    final text = g == null
        ? formatPersianNumber(value)
        : '${formatPersianNumber(value)} / ${formatPersianNumber(g)}';
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tt.bodyMedium),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: g == null || g == 0 ? 0 : (value / g).clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(height: 4),
          Text(text, style: tt.bodySmall),
        ],
      ),
    );
  }
}
