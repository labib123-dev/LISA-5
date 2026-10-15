import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/command_result.dart';

/// সাহায্য কমান্ড — "লিসা, কী কী পারো?"
///
/// LISA নিজের কাজের তালিকা:
///   ১) মুখে বলে (TTS)
///   ২) স্ক্রিনে দেখায় (বয়স্কদের পড়ার সুবিধার জন্য)
///
/// পর্ব ২ — ফাইল ১/৫
class HelpCommand {
  HelpCommand._();

  /// সংক্ষিপ্ত, মুখে বলার জন্য
  static const String spokenHelp =
      'আমি এখন সাতটি কাজ করতে পারি। '
      'এক, টর্চ জ্বালানো আর নেভানো। '
      'দুই, অ্যালার্ম দেওয়া। '
      'তিন, সময় বলা। '
      'চার, তারিখ বলা। '
      'পাঁচ, ব্যাটারি কত আছে বলা। '
      'ছয়, ভলিউম বাড়ানো আর কমানো। '
      'সাত, আপনি কী কী পারি জিজ্ঞেস করা। '
      'মনে রাখবেন, প্রতিটি কথা বলার আগে "লিসা" বলে ডাকবেন। '
      'যেমন — লিসা, টর্চ জ্বালাও।';

  /// স্ক্রিনে দেখানোর তালিকা (icon, নাম, উদাহরণ)
  static const List<List<String>> items = [
    ['🔦', 'টর্চ', 'লিসা, টর্চ জ্বালাও'],
    ['⏰', 'অ্যালার্ম', 'লিসা, সকাল সাতটার অ্যালার্ম দাও'],
    ['🕐', 'সময়', 'লিসা, কয়টা বাজে'],
    ['📅', 'তারিখ', 'লিসা, আজ কত তারিখ'],
    ['🔋', 'ব্যাটারি', 'লিসা, ব্যাটারি কত'],
    ['🔊', 'ভলিউম', 'লিসা, ভলিউম বাড়াও'],
    ['❓', 'সাহায্য', 'লিসা, কী কী পারো'],
  ];

  /// CommandRouter থেকে এই মেথডটাই কল হবে
  static Future<CommandResult> sayHelp(
    FlutterTts tts,
    Function(Widget) showOverlay,
  ) async {
    // আগে স্ক্রিনে দেখাও — তারপর বলো।
    // (awaitSpeakCompletion চালু থাকায় speak শেষ হতে ১০-১৫ সেকেন্ড লাগে,
    //  ততক্ষণ ইউজার তালিকাটা পড়তে পারবে)
    showOverlay(const HelpSheet());

    await tts.stop();
    await tts.speak(spokenHelp);

    return const CommandResult(
      success: true,
      status: CommandStatus.success,
      message: spokenHelp,
    );
  }
}

/// Overlay-এ দেখানো তালিকা
class HelpSheet extends StatelessWidget {
  const HelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF070722),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'লিসা যা যা করতে পারে',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'প্রতিটি কথা বলার আগে "লিসা" বলে ডাকবেন।',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          for (final item in HelpCommand.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item[0], style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item[1],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item[2],
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
