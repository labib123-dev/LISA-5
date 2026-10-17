// lib/core/wake_word.dart

/// "লিসা" ডাক শনাক্ত করা এবং সেটা কেটে আসল কমান্ড বের করা।
///
/// নিয়ম: ব্যবহারকারীকে আগে "লিসা" বলতেই হবে।
/// না বললে কোনো কমান্ড চালানো হবে না।
class WakeWord {
  static const String name = 'লিসা';

  /// STT যেভাবে লিখতে পারে — সব রূপ।
  /// ⚠️ 'please' নেই, 'liса' (Cyrillic) নেই — দুটোই আগের বাগ ছিল।
  static const List<String> _triggers = [
    // বাংলা লিপি
    'লিসা',
    'লিজা',
    'লিছা',
    'লিশা',
    'লিস', // STT কখনো শেষ অক্ষর কেটে দেয়
    // রোমান লিপি (STT ইংরেজিতে লিখলে)
    'lisa',
    'leesa',
    'lissa',
    'lysa',
    'liza',
    'lesa',
  ];

  /// ── ডাক শোনা গেছে কি? ──
  static bool detected(String input) => _find(input) != null;

  /// ── কমান্ড অংশটা বের করা ──
  /// "লিসা টর্চ জ্বালাও" → "টর্চ জ্বালাও"
  /// "টর্চ জ্বালাও লিসা" → "টর্চ জ্বালাও"  (পেছনে বললেও কাজ করবে)
  static String extractCommand(String input) {
    final m = _find(input);
    if (m == null) return _clean(input);

    final removed =
        input.substring(0, m.start) + ' ' + input.substring(m.end);
    return _clean(removed);
  }

  /// ডাক শব্দটা কোথায়, কতটা লম্বা — খুঁজে বের করা
  static _Match? _find(String input) {
    final lower = input.toLowerCase();
    _Match? best;

    for (final t in _triggers) {
      final tl = t.toLowerCase();
      var from = 0;

      while (true) {
        final pos = lower.indexOf(tl, from);
        if (pos < 0) break;

        // রোমান শব্দ হলে আগে-পরে অন্য অক্ষর থাকলে বাদ দাও
        // (যেমন "melisa" যেন ভুলে ট্রিগার না করে)
        if (_isLatin(tl)) {
          final before = pos > 0 ? lower[pos - 1] : ' ';
          final after = pos + tl.length < lower.length
              ? lower[pos + tl.length]
              : ' ';
          if (_isLetter(before) || _isLetter(after)) {
            from = pos + 1;
            continue;
          }
        }

        // সবচেয়ে আগের ডাকটা বেছে নাও
        if (best == null || pos < best.start) {
          best = _Match(pos, pos + tl.length);
        }
        break;
      }
    }
    return best;
  }

  static bool _isLatin(String s) => RegExp(r'^[a-z]+$').hasMatch(s);

  static bool _isLetter(String c) =>
      c.isNotEmpty && RegExp(r'[a-z0-9]').hasMatch(c);

  /// যতিচিহ্ন সরিয়ে পরিষ্কার করা
  static String _clean(String s) {
    // 🔧 ফিক্স: raw string-এ \' বা \" কাজ করে না (স্ট্রিং ভেঙে যায়)।
    //    triple-quoted raw string-এ ভেতরে ' আর " দুটোই নিরাপদ।
    var out = s.replaceAll(RegExp(r'''[,.?!;:\-।'"“”‘’]'''), ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }
}

class _Match {
  final int start;
  final int end;
  const _Match(this.start, this.end);
}
