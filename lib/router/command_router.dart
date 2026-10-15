import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../commands/alarm.dart';
import '../commands/battery.dart';
import '../commands/flashlight.dart';
import '../commands/help.dart';
import '../commands/time_date.dart';
import '../commands/volume.dart';

import '../core/intent_matcher.dart';
import '../models/command_result.dart';
import '../models/lisa_intent.dart';

/// LISA-র ব্রেন থেকে আসা intent → সঠিক কমান্ড ক্লাসে পাঠায়।
///
/// অ্যাপের পথ:
///   SpeechService (মাইক) → WakeWord → IntentMatcher → **CommandRouter** → Command
///
/// পর্ব ২ — ফাইল ২/৫
class CommandRouter {
  final FlutterTts tts;
  final Function(Widget) showOverlay;

  CommandRouter({
    required this.tts,
    required this.showOverlay,
  });

  /// একটি পরিষ্কার (wake word বাদ দেওয়া) কমান্ড চালায়।
  Future<CommandResult> route(String command) async {
    final safeCommand = command.trim();

    if (safeCommand.isEmpty) {
      const msg = 'বলুন, শুনছি।';
      await tts.speak(msg);
      return const CommandResult(
        success: false,
        status: CommandStatus.notFound,
        message: msg,
      );
    }

    final intent = IntentMatcher.detect(safeCommand);

    switch (intent) {
      // ── টর্চ ─────────────────────────────────────
      case LisaIntent.flashlightOn:
        return FlashlightCommand.turnOn(tts);

      case LisaIntent.flashlightOff:
        return FlashlightCommand.turnOff(tts);

      // ── ভলিউম ────────────────────────────────────
      case LisaIntent.volumeUp:
        return VolumeCommand.volumeUp(tts);

      case LisaIntent.volumeDown:
        return VolumeCommand.volumeDown(tts);

      // ── সময় ও তারিখ ─────────────────────────────
      case LisaIntent.tellTime:
        return TimeDateCommand.tellTime(tts);

      case LisaIntent.tellDate:
        return TimeDateCommand.tellDate(tts);

      // ── অ্যালার্ম ────────────────────────────────
      case LisaIntent.setAlarm:
        return AlarmCommand.setAlarm(tts, safeCommand, showOverlay);

      // ── ব্যাটারি ─────────────────────────────────
      case LisaIntent.batteryStatus:
        return BatteryCommand.getBatteryStatus(tts);

      // ── সাহায্য ──────────────────────────────────
      case LisaIntent.help:
        return HelpCommand.sayHelp(tts, showOverlay);

      // ── কিছুই মেলেনি ─────────────────────────────
      case LisaIntent.unknown:
        const msg = 'দুঃখিত, কমান্ডটি বুঝতে পারিনি। আবার বলুন।';
        await tts.speak(msg);
        return const CommandResult(
          success: false,
          status: CommandStatus.notFound,
          message: msg,
        );
    }
  }
}
