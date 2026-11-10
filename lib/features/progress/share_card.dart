import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/utils/persian_digits.dart';
import '../../l10n/app_localizations.dart';

/// اندازه‌ی منطقی کارت؛ خروجی ۱۰۸۰×۱۳۵۰ (۴:۵، مناسب اینستاگرام و تلگرام).
const shareCardSize = Size(300, 375);
const shareCardPixelRatio = 1080 / 300;

/// کارت اشتراک با لوگوی اپ (بخش ۱۳، موتور رشد): «قبل و بعد» یا «روز پیاپی».
class ShareCard extends StatelessWidget {
  const ShareCard.streak({super.key, required int this.streak})
    : before = null,
      after = null,
      weightChangeKg = null,
      days = null;

  const ShareCard.beforeAfter({
    super.key,
    required String this.before,
    required String this.after,
    this.weightChangeKg,
    this.days,
  }) : streak = null;

  final int? streak;
  final String? before;
  final String? after;
  final double? weightChangeKg;
  final int? days;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const white = Colors.white;
    final title = Theme.of(context).textTheme.headlineMedium!
        .copyWith(color: white, fontWeight: FontWeight.w700);
    return SizedBox.fromSize(
      size: shareCardSize,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [BrandColors.greenDeep, BrandColors.greenDarker],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const _Logo(),
              const SizedBox(height: 12),
              Expanded(
                child: streak != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 64)),
                          Text(
                            formatPersianNumber(streak!),
                            style: title.copyWith(fontSize: 72),
                          ),
                          Text(t.cardStreak, style: title),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                _Photo(path: before!, label: t.photoBefore),
                                const SizedBox(width: 8),
                                _Photo(path: after!, label: t.photoAfter),
                              ],
                            ),
                          ),
                          if (weightChangeKg != null && days != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                t.cardWeightChange(
                                  formatPersianNumber(
                                    weightChangeKg!.abs(),
                                    fractionDigits: 1,
                                  ),
                                  formatPersianNumber(days!),
                                ),
                                style: title.copyWith(fontSize: 22),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                t.cardTagline,
                style: const TextStyle(color: white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: BrandColors.orangeDeep,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 8),
      Text(
        AppLocalizations.of(context).appTitle,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path, required this.label});
  final String path;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(path), fit: BoxFit.cover),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black45,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// پیش‌نمایش کارت و اشتراک (فقط با انتخاب کاربر).
Future<void> showShareCardDialog(BuildContext context, ShareCard card) =>
    showDialog<void>(
      context: context,
      builder: (c) => _ShareDialog(card: card),
    );

class _ShareDialog extends ConsumerStatefulWidget {
  const _ShareDialog({required this.card});
  final ShareCard card;

  @override
  ConsumerState<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends ConsumerState<_ShareDialog> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    final t = AppLocalizations.of(context);
    final boundary =
        _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: shareCardPixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await ref
        .read(shareServiceProvider)
        .shareImage(bytes!.buffer.asUint8List(), text: t.shareText);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.all(12),
      content: FittedBox(
        child: RepaintBoundary(key: _key, child: widget.card),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton.icon(
          key: const Key('share-now'),
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.share),
          label: Text(t.shareNow),
        ),
      ],
    );
  }
}
