class WakeWord {
  static const List<String> _triggers = [
    // বাংলা variations
    'lisa',
    'লিসা',
    'লিছা',
    'লিশা',
    'লিজা',
    // English phonetic variations
    // STT বাংলা শব্দ ইংরেজিতে যেভাবে লিখতে পারে
    'leesa',
    'lissa',
    'lysa',
    'lesa',
    'liса',
    'lisa,',
    // Common mis-recognition
    'please',
    'lisa please',
  ];

  static bool detected(String input) {
    final cleaned = input.trim().toLowerCase();
    for (final trigger in _triggers) {
      if (cleaned.contains(trigger.trim())) {
        return true;
      }
    }
    return false;
  }

  // Command থেকে wake word সরিয়ে clean command বের করা
  // যেমন "lisa torch on" → "torch on"
  static String extractCommand(String input) {
    String cleaned = input.trim().toLowerCase();
    for (final trigger in _triggers) {
      cleaned = cleaned.replaceAll(trigger.trim(), '').trim();
    }
    // comma বা extra space সরানো
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[,\s]+'), '').trim();
    return cleaned;
  }
}
