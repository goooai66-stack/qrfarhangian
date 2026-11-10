import 'package:flutter/material.dart';

import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';

/// شمارنده‌ی آب (لیوان).
class WaterCard extends StatelessWidget {
  const WaterCard({super.key, required this.glasses, required this.onChanged});

  final int glasses;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.water_drop_outlined, color: Colors.lightBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.water,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: const Key('water-minus'),
              tooltip: t.waterRemove,
              onPressed: glasses > 0 ? () => onChanged(glasses - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  t.waterGlasses(toPersianDigits('$glasses')),
                  key: const Key('water-count'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              key: const Key('water-plus'),
              tooltip: t.waterAdd,
              onPressed: () => onChanged(glasses + 1),
              icon: const Icon(Icons.add_circle, color: Colors.lightBlue),
            ),
          ],
        ),
      ),
    );
  }
}
