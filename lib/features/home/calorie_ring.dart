import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';

/// حلقه‌ی کالری: مصرف‌شده نسبت به هدف، با «باقی‌مانده» در وسط.
class CalorieRing extends StatelessWidget {
  const CalorieRing({super.key, required this.consumed, required this.goal});

  final double consumed;
  final int? goal;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final g = goal;
    final progress = g == null || g == 0 ? 0.0 : consumed / g;
    final remaining = g == null ? null : g - consumed.round();
    final over = remaining != null && remaining < 0;

    return Semantics(
      label: '${t.kcalConsumed} ${formatPersianNumber(consumed)}',
      child: SizedBox(
        width: 180,
        height: 180,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, p, _) => CustomPaint(
            painter: _RingPainter(
              progress: p,
              track: cs.surfaceContainerHighest,
              color: over ? BrandColors.orange : cs.primary,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    remaining == null
                        ? formatPersianNumber(consumed)
                        : formatPersianNumber(remaining.abs()),
                    key: const Key('ring-value'),
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    remaining == null
                        ? t.kcalConsumed
                        : over
                        ? t.kcalConsumed
                        : t.kcalRemaining,
                    style: tt.bodyMedium,
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

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base..color = track);
    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
