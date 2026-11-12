import 'package:speech_to_text/speech_to_text.dart';

/// تبدیل گفتار به متن روی خود گوشی (صدا به سرور فرستاده نمی‌شود).
abstract interface class SpeechService {
  /// false ← تشخیص گفتار روی این گوشی در دسترس نیست یا اجازه‌ی میکروفون داده نشد.
  Future<bool> initialize();

  Future<void> start(void Function(String text, bool isFinal) onText);

  Future<void> stop();
}

class DeviceSpeechService implements SpeechService {
  final _stt = SpeechToText();

  @override
  Future<bool> initialize() async {
    try {
      return await _stt.initialize();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start(void Function(String text, bool isFinal) onText) =>
      _stt.listen(
        onResult: (r) => onText(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          localeId: 'fa_IR',
          partialResults: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
      );

  @override
  Future<void> stop() => _stt.stop();
}

class FakeSpeechService implements SpeechService {
  FakeSpeechService({this.available = true, this.text = ''});

  bool available;

  /// متنی که «شنیده» می‌شود.
  String text;
  bool listening = false;
  void Function(String, bool)? _onText;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> start(void Function(String text, bool isFinal) onText) async {
    listening = true;
    _onText = onText;
    onText(text, false);
  }

  @override
  Future<void> stop() async {
    listening = false;
    _onText?.call(text, true);
  }
}
