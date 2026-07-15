import 'package:flutter_tts/flutter_tts.dart';
import 'package:volume_controller/volume_controller.dart';

import '../models/command_result.dart';

class VolumeCommand {
  static Future<CommandResult> volumeUp(FlutterTts tts) async {
    try {
      // VolumeController() constructor নেই — singleton instance ব্যবহার করতে হয়
      double volume = await VolumeController.instance.getVolume();
      volume = (volume + 0.1).clamp(0.0, 1.0);
      await VolumeController.instance.setVolume(volume);

      final percent = (volume * 100).round();
      final msg = 'ভলিউম $percent শতাংশ করা হয়েছে।';
      await tts.speak(msg);

      return CommandResult(
        success: true,
        status: CommandStatus.success,
        message: msg,
      );
    } catch (e) {
      const msg = 'ভলিউম বাড়ানো যায়নি।';
      await tts.speak(msg);
      return const CommandResult(
        success: false,
        status: CommandStatus.failed,
        message: msg,
      );
    }
  }

  static Future<CommandResult> volumeDown(FlutterTts tts) async {
    try {
      double volume = await VolumeController.instance.getVolume();
      volume = (volume - 0.1).clamp(0.0, 1.0);
      await VolumeController.instance.setVolume(volume);

      final percent = (volume * 100).round();
      final msg = 'ভলিউম $percent শতাংশ করা হয়েছে।';
      await tts.speak(msg);

      return CommandResult(
        success: true,
        status: CommandStatus.success,
        message: msg,
      );
    } catch (e) {
      const msg = 'ভলিউম কমানো যায়নি।';
      await tts.speak(msg);
      return const CommandResult(
        success: false,
        status: CommandStatus.failed,
        message: msg,
      );
    }
  }
}
