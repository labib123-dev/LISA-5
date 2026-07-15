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
    // আগে error হয়ে থাকলে reset করে আবার চেষ্টা করা হচ্ছে
    if (_initialized && !_hasError) return true;

    // প্রতিবার initialize এর আগে state reset করা হচ্ছে
    // যাতে broken state এ আটকে না থাকে
    _initialized = false;
    _hasError = false;

    try {
      // onError callback এর timing issue এড়াতে
      // আলাদা variable এ result ধরা হচ্ছে
      bool initResult = false;

      initResult = await _speech.initialize(
        onStatus: (status) {
          print('STT Status: $status');
          // notListening মানে STT ready কিন্তু শুনছে না — এটা normal
          // error মানে কিছু একটা ভুল হয়েছে
          if (status == 'error') {
            _hasError = true;
            _initialized = false;
          }
        },
        onError: (error) {
          print('STT Error: ${error.errorMsg}');
          // onError callback এ সরাসরি _initialized = false করলে
          // race condition হয় — তাই _hasError flag ব্যবহার করছি
          // পরের initialize() call এ এটা check করা হবে
          _hasError = true;
          _initialized = false;
        },
      );

      // initialize() এর return value এবং error flag দুটোই check করছি
      // শুধু return value চেক করলে onError এর পরে আসা error miss হত
      if (initResult && !_hasError) {
        try {
          final locales = await _speech.locales();
          final hasBengali = locales.any(
            (l) => l.localeId.startsWith('bn'),
          );
          _localeId = hasBengali ? 'bn_BD' : 'en_US';
          print('LISA STT locale: $_localeId');
          _initialized = true;
        } catch (e) {
          // locale fetch fail করলেও English দিয়ে চলবে
          print('STT locale fetch error: $e');
          _localeId = 'en_US';
          _initialized = true;
        }
      } else {
        _initialized = false;
        print('STT initialize returned false or has error');
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
    // Fix 1: Already listening guard
    if (_speech.isListening) {
      print('STT: Already listening, skipping');
      return;
    }

    // Fix 5: Broken state চেক — error থাকলে আবার initialize করো
    if (!_initialized || _hasError) {
      print('STT: Reinitializing due to broken state...');
      final ready = await initialize();
      if (!ready) {
        print('STT: Reinitialization failed');
        return;
      }
    }

    try {
      await _speech.listen(
        localeId: _localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
      );
    } catch (e) {
      print('STT listen exception: $e');
      // listen fail করলে state reset করা হচ্ছে
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
  bool get hasError => _hasError;
}
