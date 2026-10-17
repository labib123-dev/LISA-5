// lib/core/intent_matcher.dart
import '../models/lisa_intent.dart';

/// একটা কমান্ড কতটা নিশ্চিতভাবে চেনা গেছে, তার ফলাফল।
class IntentMatch {
  final LisaIntent intent;
  final double score; //  0.0 – 1.0
  final String keyword; //  কোন কীওয়ার্ডে মিলেছে

  const IntentMatch(this.intent, this.score, this.keyword);

  /// যথেষ্ট নিশ্চিত? না হলে কমান্ড চালানো যাবে না।
  bool get isConfident => score >= IntentMatcher.minConfidence;

  @override
  String toString() =>
      '${intent.name} — ${(score * 100).round()}% ← "$keyword"';
}

class _Entry {
  final LisaIntent intent;
  final List<String> keywords;
  const _Entry(this.intent, this.keywords);
}

class IntentMatcher {
  /// এর নিচের স্কোর হলে কমান্ড চালানো হবে না —
  /// LISA বলবে "বুঝতে পারিনি"।
  ///
  /// ⚠️ টিউনিং:
  ///   বেশি কমান্ড মিস করলে        → 0.65 করুন
  ///   অপ্রয়োজনীয় কাজ করলে       → 0.80 করুন
  static const double minConfidence = 0.72;

  /// ── মূল ফাংশন ──
  /// CommandRouter এটাই ডাকে।
  static LisaIntent detect(String command) => match(command).intent;

  /// বিস্তারিত ফলাফল — স্কোর ও কোন শব্দে মিলেছে সহ।
  /// (Settings-এর "মাইক টেস্ট" স্ক্রিনে কাজে লাগবে)
  static IntentMatch match(String command) {
    final cmd = _normalize(command);
    if (cmd.isEmpty) return const IntentMatch(LisaIntent.unknown, 0, '');

    var best = const IntentMatch(LisaIntent.unknown, 0, '');

    // সব কীওয়ার্ড চেক করে *সবচেয়ে ভালো* ম্যাচটা নেওয়া হচ্ছে।
    // এতে আগের বাগ (একই শব্দ দুই কমান্ডে থাকলে প্রথমটা জিতে যাওয়া)
    // নিজে থেকেই ঠিক হয়ে যায়।
    for (final entry in _table) {
      for (final kw in entry.keywords) {
        final s = _score(cmd, kw);
        if (s > best.score) {
          best = IntentMatch(entry.intent, s, kw);
        }
      }
    }

    // আত্মবিশ্বাস কম → কাজ করব না।
    // "বুঝতে পারিনি" বলা > ভুল কাজ করা
    if (best.score < minConfidence) {
      return IntentMatch(LisaIntent.unknown, best.score, best.keyword);
    }
    return best;
  }

  /// ডিবাগ/টেস্ট স্ক্রিনের জন্য
  static String explain(String command) => match(command).toString();

  // ═══════════════════ স্কোরিং ═══════════════════

  static double _score(String utterance, String keyword) {
    final u = _squash(utterance);
    final k = _squash(keyword);
    if (u.isEmpty || k.isEmpty) return 0;

    // ১. সরাসরি মিলে গেছে → প্রায় নিশ্চিত
    if (u.contains(k)) {
      // লম্বা কীওয়ার্ড = বেশি নির্দিষ্ট = হালকা বাড়তি প্রাধান্য
      final bonus = k.length / 400;
      final s = 0.95 + bonus;
      return s > 1.0 ? 1.0 : s;
    }

    // ২. ছোট বাক্য হলে সরাসরি তুলনা
    if (u.length <= k.length) return _similarity(u, k);

    // ৩. বড় বাক্যের ভেতরে sliding window দিয়ে খোঁজা
    //    (যেমন: "লিজা টর্চ জালাও" → ভেতরে "টর্চ জালাও" আছে কি?)
    var best = 0.0;
    for (var i = 0; i + k.length <= u.length; i++) {
      final s = _similarity(u.substring(i, i + k.length), k);
      if (s > best) best = s;
      if (best >= 1.0) break;
    }
    return best;
  }

  /// 1.0 = হুবহু এক, 0.0 = একদম আলাদা
  static double _similarity(String a, String b) {
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - _levenshtein(a, b) / maxLen;
  }

  /// Levenshtein distance — কতটা অক্ষর বদলাতে হবে।
  /// একটা-দুটো অক্ষর ভুল হলেও কমান্ড ধরা পড়বে এটার জন্যই।
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    final m = a.length, n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;

    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;

        final del = curr[j - 1] + 1; // মুছে ফেলা
        final ins = prev[j] + 1; // যোগ করা
        final sub = prev[j - 1] + cost; // বদলানো

        var min = del < ins ? del : ins;
        if (sub < min) min = sub;
        curr[j] = min;
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  // ═══════════════════ পরিষ্কার করা ═══════════════════

  static String _normalize(String text) {
    var s = text.toLowerCase();

    // wake word সরাও — লম্বাটা আগে, নাহলে 'lisa' আলাদা হয়ে যায়
    for (final w in const [
      'ok lisa',
      'okay lisa',
      'ওকে লিসা',
      'lisa',
      'লিসা',
    ]) {
      s = s.replaceAll(w, ' ');
    }

    // 🔧 ফিক্স: raw string-এ \' কাজ করে না — triple-quoted raw string
    //    ব্যবহার করা হলো (যতিচিহ্ন, বাংলা দাঁড়ি সহ)
    s = s.replaceAll(RegExp(r'''[,.?!;:\-।'"“”‘’]'''), ' ');

    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// সব স্পেস মুছে ফেলা — বাংলা STT-র স্পেসিং অনির্ভরযোগ্য,
  /// তাই "টর্চ  জ্বালাও" আর "টর্চ জ্বালাও" এক হতেই হবে।
  static String _squash(String s) => s.replaceAll(RegExp(r'\s'), '');

  // ═══════════════════ কীওয়ার্ড টেবিল ═══════════════════
  //
  // নিয়ম:
  //   • শুধু v1-এর ৭টা ফিচার — এর বাইরে কিছু নেই
  //   • প্রতিটা কমান্ডের যত বাংলা রূপ সম্ভব দাও
  //   • একা "লাইট"/"আলো" দিও না — on/off গুলিয়ে যাবে
  //   • ছোট/একশব্দের কীওয়ার্ড এড়াও, আপনা-আপনি ভুল ধরবে

  static const _table = <_Entry>[

    // ─────────── টর্চ ───────────
    _Entry(LisaIntent.flashlightOn, [
      'torch on', 'flash on', 'light on', 'torch jalao', 'light jalao',
      'torch chalu', 'alo dao',
      'টর্চ জ্বালাও', 'টর্চ জালাও', 'টর্চ অন', 'টর্চ চালু',
      'টর্চ লাগাও', 'টর্চ দাও',
      'লাইট জ্বালাও', 'লাইট অন', 'লাইট চালু',
      'বাতি জ্বালাও', 'বাতি দাও',
      'আলো দাও', 'আলো জ্বালাও', 'ফ্ল্যাশ অন',
    ]),
    _Entry(LisaIntent.flashlightOff, [
      'torch off', 'flash off', 'light off', 'torch bondho', 'alo nibhao',
      'torch niyeo', 'alo niyeo',
      'টর্চ বন্ধ', 'টর্চ অফ', 'টর্চ নিভাও', 'টর্চ নেভাও',
      'লাইট বন্ধ', 'লাইট অফ', 'লাইট নিভাও',
      'বাতি বন্ধ', 'বাতি নিভাও',
      'আলো নিভাও', 'ফ্ল্যাশ অফ',
    ]),

    // ─────────── ভলিউম ───────────
    _Entry(LisaIntent.volumeUp, [
      'volume up', 'sound up', 'volume barao', 'awaj barao',
      'ভলিউম বাড়াও', 'সাউন্ড বাড়াও', 'শব্দ বাড়াও', 'আওয়াজ বাড়াও',
    ]),
    _Entry(LisaIntent.volumeDown, [
      'volume down', 'sound down', 'volume kamao', 'awaj kamao',
      'ভলিউম কমাও', 'সাউন্ড কমাও', 'শব্দ কমাও', 'আওয়াজ কমাও',
    ]),

    // ─────────── সময় ───────────
    // ⚠️ একা 'time' দিও না — "টাইমার" বললে সময় বলে ফেলবে!
    _Entry(LisaIntent.tellTime, [
      'what time', 'time koto', 'koyta baje', 'somoy koto',
      'কয়টা বাজে', 'সময় কত', 'কত সময়', 'এখন কতটা',
    ]),

    // ─────────── তারিখ ───────────
    _Entry(LisaIntent.tellDate, [
      'date', 'today date', 'tarikh', 'aj koto tarikh',
      'আজ কত তারিখ', 'তারিখ কত', 'আজকের তারিখ',
    ]),

    // ─────────── অ্যালার্ম ───────────
    _Entry(LisaIntent.setAlarm, [
      'alarm', 'set alarm', 'alarm dao', 'alarm set',
      'অ্যালার্ম', 'অ্যালার্ম দাও', 'অ্যালার্ম সেট',
    ]),

    // ─────────── ব্যাটারি ───────────
    _Entry(LisaIntent.batteryStatus, [
      'battery', 'charge koto', 'battery koto',
      'ব্যাটারি', 'চার্জ কত', 'ব্যাটারি কত',
    ]),

    // ─────────── সাহায্য ───────────
    _Entry(LisaIntent.help, [
      'help', 'ki ki paro', 'ki korte paro',
      'কী কী পারো', 'কি কি পারো', 'কী করতে পারো', 'সাহায্য', 'হেল্প',
    ]),
  ];
}
