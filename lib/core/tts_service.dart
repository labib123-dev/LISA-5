// lib/core/tts_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LISA-র কথা বলা — পুরো অ্যাপে একটাই instance।
///
/// 🔧 বাগ ১ ফিক্স:
///   আগে _checkBengali() শুধু true/false দিত, তারপর কোড
///   জোর করে 'bn-BD' বসাত। ফলে ফোনে bn-IN থাকলে (bn-BD না থাকলে)
///   setLanguage ফেল করত এবং LISA একদম চুপ থাকত — অথচ wizard
///   "বাংলা কণ্ঠ ঠিক আছে" দেখাত।
///
///   এখন _findBengaliLocale() আসল locale id-টাই ফেরায়,
///   আর সেটাই setLanguage-এ যায়।
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();

  bool _ready = false;

  /// ফোনে বাংলা কণ্ঠ আছে কি না।
  /// না থাকলে first-run wizard ইউজারকে ইনস্টল করতে বলবে।
  bool _bengali = false;
  bool get bengaliAvailable => _bengali;

  /// আসলে যে locale ব্যবহার হচ্ছে (ডিবাগ/সেটিংস স্ক্রিনে দেখানোর জন্য)
  /// উদাহরণ: 'bn-BD' | 'bn-IN' | 'en-US'
  String _language = 'bn-BD';
  String get language => _language;

  /// ── প্রস্তুত করা ──
  Future<void> init() async {
    // Settings থেকে ইউজারের পছন্দ পড়া
    final prefs = await SharedPreferences.getInstance();
    final rate = prefs.getDouble('tts_speed') ?? 0.45;
    final pitch = prefs.getDouble('tts_pitch') ?? 1.0;

    // ── বাংলা কণ্ঠ আছে কি না ──
    //
    // ⚠️ isLanguageAvailable() কখনো কখনো অনির্দিষ্টকাল আটকে যায়
    //    (TTS engine ইনস্টল না থাকলে)। তাই timeout দরকার।
    //
    // 🔧 এখন locale id-টাই ফেরে — শুধু true/false নয়
    final bengali = await _findBengaliLocale();

    _bengali = bengali != null;
    _language = bengali ?? 'en-US'; // ✅ যেটা সত্যিই পাওয়া গেছে

    await _tts.setLanguage(_language);

    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(rate);
    await _tts.setVolume(1.0);

    // speak() যেন কথা শেষ হওয়া পর্যন্ত অপেক্ষা করে —
    // নাহলে LISA নিজের কথা শুনে ফেলবে
    await _tts.awaitSpeakCompletion(true);

    _ready = true;
    debugPrint('LISA TTS: $_language (bengali=$_bengali, rate=$rate)');
  }

  /// ফোনে যে বাংলা locale আসলে আছে, তার id ফেরায়।
  /// একটাও না থাকলে null।
  Future<String?> _findBengaliLocale() async {
    for (final id in const ['bn-BD', 'bn-IN', 'bn_BD', 'bn_IN']) {
      try {
        final r = await _tts
            .isLanguageAvailable(id)
            .timeout(const Duration(seconds: 3));

        // null আসতে পারে (কিছু ডিভাইসে) → শুধু true নিলে হবে
        if (r == true) return id;
      } catch (e) {
        debugPrint('TTS isLanguageAvailable($id) failed: $e');
        break; // engine-ই নেই, বাকিগুলো চেষ্টা করে লাভ নেই
      }
    }
    return null;
  }

  /// ── কথা বলা ──
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    if (!_ready) {
      try {
        await init();
      } catch (e) {
        debugPrint('TTS late-init failed: $e');
        return;
      }
    }

    try {
      // আগের বাক্য থামাও — নাহলে দুটো কথা একসাথে মিশে যাবে
      await _tts.stop();

      if (!_bengali) {
        // বাংলা কণ্ঠ নেই। ইংরেজি engine বাংলা লিপি পড়তে পারে না,
        // তাই কিছুই শোনা যাবে না। এটা লগ করছি যাতে বোঝা যায়।
        debugPrint('TTS warning: no Bengali voice — "$text" may be silent');
      }

      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  // ── Settings থেকে পরিবর্তন ──

  Future<void> setRate(double value) async {
    try {
      await _tts.setSpeechRate(value);
    } catch (e) {
      debugPrint('TTS setRate error: $e');
    }
  }

  Future<void> setPitch(double value) async {
    try {
      await _tts.setPitch(value);
    } catch (e) {
      debugPrint('TTS setPitch error: $e');
    }
  }

  /// Settings পেজের "Voice check" বাটনের জন্য
  Future<void> test() => speak(
        _bengali
            ? 'আসসালামু আলাইকুম, আমি লিসা। বাংলা কণ্ঠ ঠিক আছে।'
            : 'Hello, I am LISA.',
      );

  FlutterTts get engine => _tts;
}
