import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../core/speech_service.dart';
import '../commands/flashlight.dart';
import '../commands/phone_call.dart';
import '../commands/message.dart';
import '../commands/alarm.dart';

class HomePageUpdated extends StatefulWidget {
  final bool isListening;
  final String spokenText;
  final VoidCallback onMicTap;
  final FlutterTts tts;
  final SpeechService speechService;
  final Function(int) onPageChanged;
  final Function(Widget) showOverlay;

  const HomePageUpdated({
    super.key,
    required this.isListening,
    required this.spokenText,
    required this.onMicTap,
    required this.tts,
    required this.speechService,
    required this.onPageChanged,
    required this.showOverlay,
  });

  @override
  State<HomePageUpdated> createState() => _HomePageUpdatedState();
}

class _HomePageUpdatedState extends State<HomePageUpdated> {
  int selectedIndex = 0;
  bool _torchOn = false;

  // Fix 3: আলাদা STT instance — main listener এর সাথে conflict নেই
  final SpeechToText _quickSpeech = SpeechToText();

  // Fix 10: Quick action এর visual state
  bool _quickListening = false;
  String _quickPrompt = '';
  String _activeAction = '';

  Future<void> _listenForQuickAction({
    required String action,
    required String prompt,
    required Future<void> Function(String text) onFinalResult,
  }) async {
    // main listener চলছে বা quick listener চলছে — skip
    if (widget.speechService.isListening || _quickListening) return;

    // Fix 10: Visual feedback — user কে জানাও কোন action এর জন্য শুনছে
    setState(() {
      _quickListening = true;
      _quickPrompt = prompt;
      _activeAction = action;
    });

    await widget.tts.speak(prompt);

    final initialized = await _quickSpeech.initialize();
    if (!initialized) {
      await widget.tts.speak('মাইক্রোফোন চালু করা যায়নি।');
      setState(() {
        _quickListening = false;
        _quickPrompt = '';
        _activeAction = '';
      });
      return;
    }

    String finalText = '';

    await _quickSpeech.listen(
      listenMode: ListenMode.confirmation,
      partialResults: false,
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      onResult: (result) {
        if (result.finalResult) {
          finalText = result.recognizedWords;
        }
      },
    );

    await Future.delayed(const Duration(seconds: 9));

    // Fix 10: Listening শেষ — visual feedback সরিয়ে দাও
    setState(() {
      _quickListening = false;
      _quickPrompt = '';
      _activeAction = '';
    });

    if (finalText.isNotEmpty) {
      await onFinalResult(finalText);
    } else {
      await widget.tts.speak('বুঝতে পারিনি, আবার চেষ্টা করুন।');
    }
  }

  Future<void> _handleQuickAction(String action) async {
    if (action == 'torch') {
      if (_torchOn) {
        await FlashlightCommand.turnOff(widget.tts);
        setState(() => _torchOn = false);
      } else {
        await FlashlightCommand.turnOn(widget.tts);
        setState(() => _torchOn = true);
      }
      return;
    }

    if (action == 'call') {
      await _listenForQuickAction(
        action: 'call',
        prompt: 'কাকে কল করব? নম্বর বলুন।',
        onFinalResult: (text) async {
          final number = RegExp(r'[\d]+').stringMatch(text) ?? '';
          if (number.isNotEmpty) {
            await PhoneCallCommand.callNumber(widget.tts, number);
          } else {
            await widget.tts.speak('নম্বর বুঝতে পারিনি।');
          }
        },
      );
      return;
    }

    if (action == 'message') {
      await _listenForQuickAction(
        action: 'message',
        prompt: 'কাকে মেসেজ পাঠাব? নম্বর বলুন।',
        onFinalResult: (text) async {
          final number = RegExp(r'[\d]+').stringMatch(text) ?? '';
          if (number.isNotEmpty) {
            await MessageCommand.sendMessage(widget.tts, number, '');
          } else {
            await widget.tts.speak('নম্বর বুঝতে পারিনি।');
          }
        },
      );
      return;
    }

    if (action == 'alarm') {
      await _listenForQuickAction(
        action: 'alarm',
        prompt: 'কয়টায় অ্যালার্ম দেব? সময় বলুন।',
        onFinalResult: (text) async {
          await AlarmCommand.setAlarm(widget.tts, text, widget.showOverlay);
        },
      );
      return;
    }
  }

  @override
  void dispose() {
    _quickSpeech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070722),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LISA', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text('Personal Assistant', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  Container(
                    width: 52, height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF44D7FF)]),
                    ),
                    child: const Center(child: Text('LISA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Fix 10: status text — quick action listening এর সময়
              // আলাদা message দেখায়
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _quickListening
                    ? Container(
                        key: const ValueKey('quick'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mic, color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _quickPrompt,
                              style: const TextStyle(color: Colors.orange, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        key: const ValueKey('status'),
                        widget.isListening
                            ? 'শুনছি...'
                            : 'হ্যালো! আমি LISA। সবসময় আপনার পাশে।',
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
              ),

              const SizedBox(height: 20),

              // Mic Button
              GestureDetector(
                onTap: widget.onMicTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isListening ? Colors.redAccent : const Color(0xFF4B43D8),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: widget.isListening
                              ? [Colors.red, Colors.redAccent]
                              : [const Color(0xFF6F7BFF), const Color(0xFF4DD8FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.isListening ? Colors.red : const Color(0xFF6F7BFF)).withOpacity(0.5),
                            blurRadius: widget.isListening ? 30 : 20,
                            spreadRadius: widget.isListening ? 8 : 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white, size: 48,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                widget.isListening ? 'বলুন...' : 'ট্যাপ করে বলুন',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),

              if (widget.spokenText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111133),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.spokenText,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text('QUICK ACTIONS', style: TextStyle(color: Colors.white54, letterSpacing: 1, fontSize: 12)),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(child: _actionButton('📞 কল করুন', () => _handleQuickAction('call'), false, 'call')),
                  const SizedBox(width: 12),
                  Expanded(child: _actionButton('💬 মেসেজ', () => _handleQuickAction('message'), false, 'message')),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: _actionButton('⏰ অ্যালার্ম', () => _handleQuickAction('alarm'), false, 'alarm')),
                  const SizedBox(width: 12),
                  Expanded(child: _actionButton(_torchOn ? '🔦 টর্চ বন্ধ' : '🔦 টর্চ', () => _handleQuickAction('torch'), _torchOn, 'torch')),
                ],
              ),

              const Spacer(),

              // Bottom Navigation
              Container(
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D2F),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navItem(0, Icons.home_outlined, 'Home'),
                    _navItem(1, Icons.note_outlined, 'Notes'),
                    _navItem(2, Icons.history, 'History'),
                    _navItem(3, Icons.settings_outlined, 'Settings'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fix 10: button active হলে orange highlight দেখাবে
  // যাতে user বুঝতে পারে কোন button এর জন্য শুনছে
  Widget _actionButton(String title, VoidCallback onTap, bool active, String action) {
    final isActiveListening = _quickListening && _activeAction == action;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: isActiveListening
              ? Colors.orange.withOpacity(0.2)
              : active
                  ? const Color(0xFF6F7BFF).withOpacity(0.3)
                  : const Color(0xFF111133),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActiveListening
                ? Colors.orange
                : active
                    ? const Color(0xFF6F7BFF)
                    : const Color(0xFF2A2A66),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isActiveListening) ...[
                const Icon(Icons.mic, color: Colors.orange, size: 14),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(
                  color: isActiveListening
                      ? Colors.orange
                      : active
                          ? const Color(0xFF6F7BFF)
                          : Colors.white,
                  fontSize: 13,
                  fontWeight: (isActiveListening || active) ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => selectedIndex = index);
        widget.onPageChanged(index);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: selected ? const Color(0xFF6F7BFF) : Colors.white54),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: selected ? const Color(0xFF6F7BFF) : Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
