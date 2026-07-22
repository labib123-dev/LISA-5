import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _hasError = false;
  String _localeId = 'en_US';

  Future<bool> initialize() async {
    if (_initialized && !_hasError) return true;

    _initialized = false;
    _hasError = false;

    try {
      bool initResult = false;

      initResult = await _speech.initialize(
        onStatus: (status) {
          print('STT Status: $status');
          if (status == 'error') {
            _hasError = true;
            _initialized = false;
          }
        },
        onError: (error) {
          print('STT Error: ${error.errorMsg}');
          _hasError = true;
          _initialized = false;
        },
      );

      if (initResult && !_hasError) {
        try {
          final locales = await _speech.locales();
          final hasBengali = locales.any(
            (l) => l.localeId.startsWith('bn'),
          );
          _localeId = hasBengali ? 'bn_BD' : 'en_US';
          print('LISA STT locale: $_localeId');
        } catch (e) {
          print('STT locale error: $e');
          _localeId = 'en_US';
        }
        _initialized = true;
      } else {
        _initialized = false;
      }
    } catch (e) {
      print('STT initialize exception: $e');
      _initialized = false;
      _hasError = true;
    }

    return _initialized;
  }

  Future<void> startListening({
    required Function(String text) onResult,
  }) async {
    if (_speech.isListening) {
      print('STT: Already listening');
      return;
    }

    if (!_initialized || _hasError) {
      final ready = await initialize();
      if (!ready) return;
    }

    try {
      await _speech.listen(
        localeId: _localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          // partial বা final যেকোনো result screen এ দেখানো হচ্ছে
          // এতে user দেখতে পাবে সে কী বলছে
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
      );
    } catch (e) {
      print('STT listen error: $e');
      _initialized = false;
      _hasError = true;
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      print('STT stop error: $e');
    }
  }

  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (e) {
      print('STT cancel error: $e');
    }
  }

  bool get isListening => _speech.isListening;
  bool get isInitialized => _initialized;
}
