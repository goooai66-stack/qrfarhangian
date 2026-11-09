import 'package:flutter/material.dart';

import '../../core/utils/jalali_date.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/date_names.dart';

/// نوار تاریخ شمسی: یک هفته (شنبه تا جمعه) با رفتن به هفته‌ی قبل/بعد.
/// روزهای آینده غیرفعال‌اند.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final start = startOfWeek(selected);
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    final nextWeek = DateTime(start.year, start.month, start.day + 7);

    return Row(
      children: [
        IconButton(
          key: const Key('date-prev-week'),
          tooltip: t.prevWeek,
          // آیکون‌های chevron در RTL خودکار آینه می‌شوند: chevron_left در
          // سمت راست به بیرون (گذشته) اشاره می‌کند.
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onSelect(
            DateTime(selected.year, selected.month, selected.day - 7),
          ),
        ),
        for (final d in days)
          Expanded(
            child: _Day(
              key: Key('day-${dayKey(d)}'),
              label: t.weekdayShort(d),
              number: toPersianDigits('${jalaliDay(d)}'),
              selected: d == selected,
              isToday: d == today,
              enabled: !d.isAfter(today),
              onTap: () => onSelect(d),
              cs: cs,
              tt: tt,
            ),
          ),
        IconButton(
          key: const Key('date-next-week'),
          tooltip: t.nextWeek,
          icon: const Icon(Icons.chevron_right),
          onPressed: nextWeek.isAfter(today)
              ? (selected == today ? null : () => onSelect(today))
              : () => onSelect(
                  DateTime(selected.year, selected.month, selected.day + 7),
                ),
        ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    super.key,
    required this.label,
    required this.number,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final String label, number;
  final bool selected, isToday, enabled;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? cs.onPrimary
        : enabled
        ? cs.onSurface
        : cs.onSurface.withValues(alpha: 0.3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.primary : null,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !selected
                ? Border.all(color: cs.primary, width: 1.5)
                : null,
          ),
          child: Column(
            children: [
              Text(label, style: tt.bodySmall?.copyWith(color: fg)),
              Text(
                number,
                style: tt.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
