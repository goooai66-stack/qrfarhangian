import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/nutrition/nutrition_types.dart';
import '../../l10n/app_localizations.dart';
import 'logging_labels.dart';

/// منوی «ثبت غذا» (بخش ۵-۱): عکس | گالری | جستجو | صوتی + غذاهای اخیر.
///
/// غذاهای اخیر داخل همین منو هستند تا ثبت تکراری ۳ لمس بماند:
/// «ثبت غذا» ← غذای اخیر ← «ثبت».
/// عکس و گالری در مرحله‌ی ۳ و صوتی در مرحله‌ی ۶ فعال می‌شوند.
Future<void> showLogFoodSheet(
  BuildContext context, {
  required MealType meal,
  required DateTime day,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _LogFoodSheet(meal: meal, day: day, parent: context),
);

class _LogFoodSheet extends ConsumerWidget {
  const _LogFoodSheet({
    required this.meal,
    required this.day,
    required this.parent,
  });

  final MealType meal;
  final DateTime day;

  /// context صفحه‌ی زیرین؛ مسیریابی بعد از بستن منو از آن انجام می‌شود.
  final BuildContext parent;

  static const _maxRecent = 6;

  void _go(BuildContext sheet, String location) {
    Navigator.of(sheet).pop();
    parent.push(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final repo = ref.watch(foodRepositoryProvider).value;
    final recentIds = ref.watch(recentFoodIdsProvider).value ?? const [];
    final recent = [
      for (final id in recentIds.take(_maxRecent)) ?repo?.byId(id),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.logSheetTitle(t.mealLabel(meal)),
              style: tt.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Action(
                  icon: Icons.photo_camera_outlined,
                  label: t.actionCamera,
                  soon: t.comingSoon,
                ),
                _Action(
                  icon: Icons.photo_library_outlined,
                  label: t.actionGallery,
                  soon: t.comingSoon,
                ),
                _Action(
                  key: const Key('action-search'),
                  icon: Icons.search,
                  label: t.actionSearch,
                  onTap: () =>
                      _go(context, Routes.searchFor(meal: meal, day: day)),
                ),
                _Action(
                  icon: Icons.mic_none,
                  label: t.actionVoice,
                  soon: t.comingSoon,
                ),
              ],
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(t.sectionRecent, style: tt.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in recent)
                    ActionChip(
                      key: Key('sheet-food-${f.id}'),
                      avatar: const Icon(Icons.history, size: 18),
                      label: Text(f.nameFa),
                      onPressed: () => _go(
                        context,
                        Routes.foodFor(foodId: f.id, meal: meal, day: day),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.soon,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// برچسب «به‌زودی» برای گزینه‌های غیرفعال.
  final String? soon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final fg = enabled
        ? cs.onPrimaryContainer
        : cs.onSurface.withValues(alpha: 0.38);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: enabled ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Icon(icon, size: 30, color: fg),
                  const SizedBox(height: 6),
                  Text(label, style: tt.labelLarge?.copyWith(color: fg)),
                  // جای خط «به‌زودی» همیشه رزرو می‌شود تا کاشی‌ها هم‌قد باشند.
                  Visibility(
                    visible: !enabled && soon != null,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Text(
                      soon ?? '',
                      style: tt.labelSmall?.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
