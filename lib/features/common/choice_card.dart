import 'package:flutter/material.dart';

/// کارت انتخاب بزرگ (برای آنبوردینگ)، با حالت غیرفعال و توضیح.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.enabled = true,
    this.disabledReason,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final String? disabledReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: fg, size: 28),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: tt.bodyMedium?.copyWith(color: fg),
                        ),
                      if (!enabled && disabledReason != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            disabledReason!,
                            style: tt.bodySmall?.copyWith(color: cs.error),
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
