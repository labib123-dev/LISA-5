// lib/core/speech_service.dart
import 'package:flutter/foundation.dart';
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

  /// LISA যে ভাষায় শুনবে (initialize() ঠিক করে)
  String _localeId = 'en_US';

  /// ডিফল্ট সময় — main.dart/wizard চাইলে প্রতি কলে বদলাতে পারে
  static const Duration defaultListenFor = Duration(seconds: 8);
  static const Duration defaultPauseFor = Duration(seconds: 2);

  /// ── প্রস্তুত করা ──
  Future<bool> initialize() async {
    if (_initialized && !_hasError) return true;

    _initialized = false;
    _hasError = false;

    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          debugPrint('STT Status: $status');
          // 'done' বা 'notListening' স্বাভাবিক সমাপ্তি — error নয়
          if (status == 'error') {
            _hasError = true;
            _initialized = false;
          }
        },
        onError: (error) {
          debugPrint('STT Error: ${error.errorMsg}');
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
        debugPrint('LISA STT locale: $_localeId');
      } catch (e) {
        debugPrint('STT locale error: $e');
        _localeId = 'en_US';
      }

      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('STT initialize exception: $e');
      _initialized = false;
      _hasError = true;
      return false;
    }
  }

  /// ── শোনা শুরু ──
  ///
  /// ⚠️ `onResult` দুইটা argument দেয়:
  ///     text    → STT যা লিখল
  ///     isFinal → সত্যিকারের ফলাফল কি না
  /// এটাই hands-free বাগের সমাধান — partial-এ কমান্ড চলবে না।
  ///
  /// `listenFor` = কত সেকেন্ড শুনবে, `pauseFor` = কত সেকেন্ড চুপ থাকলে শেষ।
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Duration listenFor = defaultListenFor,
    Duration pauseFor = defaultPauseFor,
  }) async {
    if (_speech.isListening) {
      debugPrint('STT: Already listening');
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

        listenFor: listenFor,
        pauseFor: pauseFor,

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
      debugPrint('STT listen error: $e');
      _initialized = false;
      _hasError = true;
    }
  }

  /// স্বাভাবিকভাবে থামানো — এখন যা পাওয়া গেছে সেটা থাকবে
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('STT stop error: $e');
    }
  }

  /// বাতিল করা — `stop`-এর চেয়ে কড়া, কোনো ফলাফল দেবে না
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('STT cancel error: $e');
    }
  }

  bool get isListening => _speech.isListening;
  bool get isInitialized => _initialized;
  bool get hasError => _hasError;

  /// first_run_wizard ও হোম স্ক্রিন এটা পড়ে (বাংলা আছে কি না জানতে)
  String get localeId => _localeId;
}
