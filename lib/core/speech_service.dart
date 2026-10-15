// lib/core/speech_service.dart
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// মাইক্রোফোন ও স্পিচ রিকগনিশনের একমাত্র দায়িত্বপ্রাপ্ত ক্লাস।
/// পুরো অ্যাপে একটাই instance চলবে (singleton)।
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;
  bool _hasError = false;

  /// LISA যে ভাষায় শুনবে
  String _localeId = 'en_US';

  /// কত সেকেন্ড শুনবে — টানা কথা না বললে এতক্ষণ পরে বন্ধ
  static const Duration _listenFor = Duration(seconds: 8);

  /// কত সেকেন্ড চুপ থাকলে "বলা শেষ" ধরে নেবে
  static const Duration _pauseFor = Duration(seconds: 2);

  /// ── প্রস্তুত করা ──
  Future<bool> initialize() async {
    if (_initialized && !_hasError) return true;

    _initialized = false;
    _hasError = false;

    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          debugLog('STT Status: $status');
          // 'done' বা 'notListening' স্বাভাবিক সমাপ্তি — error নয়
          if (status == 'error') {
            _hasError = true;
            _initialized = false;
          }
        },
        onError: (error) {
          debugLog('STT Error: ${error.errorMsg}');
          _hasError = true;
          _initialized = false;
        },
      );

      if (!ok) {
        _initialized = false;
        return false;
      }

      // ── ভাষা বাছাই ──
      // টার্গেট: বাংলা। না পেলে ইংরেজিতে শুনবে
      // (ইংরেজি fallback ছাড়া অ্যাপ একদমই কিছু শুনবে না)।
      try {
        final locales = await _speech.locales();
        final hasBengali = locales.any((l) => l.localeId.startsWith('bn'));

        if (hasBengali) {
          // bn-IN সাধারণত বেশি ডিভাইসে থাকে, bn_BD কম
          final ids = locales
              .where((l) => l.localeId.startsWith('bn'))
              .map((l) => l.localeId)
              .toList();

          _localeId = ids.contains('bn_BD') ? 'bn_BD' : ids.first;
        } else {
          _localeId = 'en_US';
        }
        debugLog('LISA STT locale: $_localeId');
      } catch (e) {
        debugLog('STT locale error: $e');
        _localeId = 'en_US';
      }

      _initialized = true;
      return true;
    } catch (e) {
      debugLog('STT initialize exception: $e');
      _initialized = false;
      _hasError = true;
      return false;
    }
  }

  /// ── শোনা শুরু ──
  ///
  /// ⚠️ `onResult` এখন *দুইটা* argument দেয়:
  ///     text    → STT যা লিখল
  ///     isFinal → সত্যিকারের ফলাফল কি না
  ///
  /// এটাই hands-free বাগের সমাধান। আগে আধা-বাক্যেও কমান্ড
  /// চালানো হচ্ছিল, তাই "লিসা" বলার সাথে সাথে লিসেনিং বন্ধ হয়ে
  /// যেত আর আসল কমান্ডটা কখনো পৌঁছাত না।
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
  }) async {
    if (_speech.isListening) {
      debugLog('STT: Already listening');
      return;
    }

    if (!_initialized || _hasError) {
      final ready = await initialize();
      if (!ready) return;
    }

    try {
      await _speech.listen(
        localeId: _localeId,

        // dictation = লম্বা লেখার জন্য (নোট, ইমেইল)
        // search    = ছোট বাক্য/কমান্ডের জন্য ← আমাদের দরকার
        listenMode: ListenMode.search,

        partialResults: true,

        listenFor: _listenFor,
        pauseFor: _pauseFor,

        // অনলাইন মডেল ব্যবহার করতে দাও — বাংলায় অনেক ভালো বোঝে।
        // (অফলাইনে জোর করলে বাংলা প্রায়ই কাজ করে না)
        onDevice: false,
        cancelOnError: true,

        onResult: (SpeechRecognitionResult result) {
          final text = result.recognizedWords;
          if (text.isEmpty) return;
          onResult(text, result.finalResult);
        },
      );
    } catch (e) {
      debugLog('STT listen error: $e');
      _initialized = false;
      _hasError = true;
    }
  }

  /// স্বাভাবিকভাবে থামানো — এখন যা পাওয়া গেছে সেটা থাকবে
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugLog('STT stop error: $e');
    }
  }

  /// বাতিল করা — `stop`-এর চেয়ে কড়া, কোনো ফলাফল দেবে না
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (e) {
      debugLog('STT cancel error: $e');
    }
  }

  bool get isListening => _speech.isListening;
  bool get isInitialized => _initialized;
  bool get hasError => _hasError;
  String get localeId => _localeId;
}
