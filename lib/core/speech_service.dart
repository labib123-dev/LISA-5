import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  String _localeId = 'en_US'; // default fallback

  Future<bool> initialize() async {
    if (_initialized) return true;

    _initialized = await _speech.initialize(
      onStatus: (status) => print('Speech Status: $status'),
      onError: (error) => print('Speech Error: $error'),
    );

    if (_initialized) {
      // Phone এ Bengali (bn_BD) আছে কিনা চেক করি।
      // না থাকলে English এ fallback করব যাতে mic অন্তত কাজ করে।
      final locales = await _speech.locales();
      final hasBengali = locales.any(
        (l) => l.localeId.startsWith('bn'),
      );
      _localeId = hasBengali ? 'bn_BD' : 'en_US';
      print('Using locale: $_localeId');
    }

    return _initialized;
  }

  Future<void> startListening({
    required Function(String text) onResult,
  }) async {
    if (!_initialized) {
      final ready = await initialize();
      if (!ready) return;
    }

    await _speech.listen(
      localeId: _localeId,
      // dictation mode ব্যবহার করছি — এটা continuous listening করে
      // এবং partial results দেয়, তাই mic চালু হলে সাথে সাথে
      // animation ও response পাওয়া যাবে।
      listenMode: ListenMode.dictation,
      partialResults: true,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          onResult(result.recognizedWords);
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
  }

  bool get isListening => _speech.isListening;
}
