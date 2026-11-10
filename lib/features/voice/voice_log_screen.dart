import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/analytics/analytics.dart';
import '../../core/recognition/food_recognizer.dart';
import '../../data/db/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../common/persian_counter.dart';

/// ثبت صوتی (نگه دار و بگو) و متنی آزاد (بخش ۴-۲، ۸-۴).
/// صدا روی گوشی به متن تبدیل می‌شود؛ فقط متن به سرور می‌رود ← همان صفحه‌ی نتیجه.
class VoiceLogScreen extends ConsumerStatefulWidget {
  const VoiceLogScreen({super.key, this.meal, this.day});

  final MealType? meal;
  final DateTime? day;

  @override
  ConsumerState<VoiceLogScreen> createState() => _VoiceLogScreenState();
}

class _VoiceLogScreenState extends ConsumerState<VoiceLogScreen> {
  final _text = TextEditingController();
  bool _listening = false;
  bool _spoken = false;
  bool _busy = false;
  bool? _speechAvailable;

  @override
  void initState() {
    super.initState();
    ref.read(speechServiceProvider).initialize().then((ok) {
      if (mounted) setState(() => _speechAvailable = ok);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (_speechAvailable != true || _busy) return;
    setState(() {
      _listening = true;
      _spoken = true;
    });
    await ref.read(speechServiceProvider).start((text, isFinal) {
      if (!mounted) return;
      setState(() => _text.text = text);
    });
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    await ref.read(speechServiceProvider).stop();
    if (!mounted) return;
    setState(() => _listening = false);
    if (_text.text.trim().isNotEmpty) await _submit();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final text = _text.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(textFoodParserProvider).parse(text);
      if (!mounted) return;
      if (!result.isFood || result.items.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(t.voiceNotFood)));
      } else {
        ref.read(analyticsProvider).track(AnalyticsEvent.voiceLog);
        final meal = result.meal ?? widget.meal;
        context.pushReplacement(
          Routes.scanPreset(meal: meal, day: widget.day),
          extra: (
            result: result,
            source: _spoken ? LogSource.voice : LogSource.text,
          ),
        );
      }
    } on RecognitionException catch (e) {
      final msg = switch (e.kind) {
        ApiErrorKind.voiceQuotaExceeded => t.voiceQuota,
        ApiErrorKind.offline => t.scanOfflineTitle,
        ApiErrorKind.timeout => t.scanTimeout,
        ApiErrorKind.busy => t.scanBusy,
        ApiErrorKind.rateLimited => t.scanRateLimited,
        _ => t.scanError,
      };
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.voiceTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(t.voiceHint, textAlign: TextAlign.center, style: tt.bodyLarge),
            const SizedBox(height: 32),
            Center(
              child: GestureDetector(
                key: const Key('voice-hold'),
                onLongPressStart: (_) => _startListening(),
                onLongPressEnd: (_) => _stopListening(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _listening ? 140 : 120,
                  height: _listening ? 140 : 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _speechAvailable == false
                        ? cs.surfaceContainerHighest
                        : _listening
                        ? cs.error
                        : cs.primary,
                  ),
                  child: Icon(
                    _listening ? Icons.mic : Icons.mic_none,
                    size: 56,
                    color: _speechAvailable == false
                        ? cs.outline
                        : cs.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _speechAvailable == false
                  ? t.voiceUnavailable
                  : _listening
                  ? t.voiceListening
                  : t.voiceHold,
              textAlign: TextAlign.center,
              style: tt.titleMedium,
            ),
            const SizedBox(height: 32),
            TextField(
              key: const Key('voice-text'),
              controller: _text,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              buildCounter: persianCounter,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: t.voiceTypeHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('voice-send'),
              onPressed: _busy || _text.text.trim().isEmpty ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(t.voiceSend),
            ),
          ],
        ),
      ),
    );
  }
}
