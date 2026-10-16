// lib/ui/homepage_updated.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../commands/help.dart';
import '../core/speech_service.dart';
import 'widgets/lisa_bottom_nav.dart';

/// LISA v1 — হোম স্ক্রিন (পর্ব ৩ — ফাইল ১/৫)
///
/// ⚠️ ইচ্ছাকৃতভাবে যা নেই:
///   • on-screen slider / brightness (v1-এ বাদ)
///   • Quick action (কল / মেসেজ) — ওই command ফাইলগুলো ডিলিট করা
///   • ভেতরে দ্বিতীয় STT listener (_quickCompleter) — এটাই ছিল
///     পুরনো সবচেয়ে বড় বাগ (partial result-এ আগেই fire হতো)
///
/// এখন সব কমান্ড main.dart-এর একটাই লিসেনার দিয়ে চলে,
/// আর হোম স্ক্রিন শুধু দেখায় + মাইক ট্যাপ নেয়।
class HomePageUpdated extends StatefulWidget {
  final bool isListening;
  final String spokenText;
  final VoidCallback onMicTap;

  /// HelpCommand.sayHelp() এর জন্য দরকার
  final FlutterTts tts;

  /// মাইকে সমস্যা হলে ব্যানার দেখাতে ব্যবহৃত
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

class _HomePageUpdatedState extends State<HomePageUpdated>
    with SingleTickerProviderStateMixin {
  // ══ রং ══════════════════════════════════════════
  static const Color _bg = Color(0xFF0D0000);
  static const Color _card = Color(0xFF111133);
  static const Color _border = Color(0xFF2A2A66);
  static const Color _accent = Color(0xFF6F7BFF);
  static const Color _listenRed = Color(0xFFFF4D4D);

  /// উদাহরণ — শুধু দেখানোর জন্য (ট্যাপ করার দরকার নেই)
  static const List<String> _examples = [
    'লিসা, টর্চ জ্বালাও',
    'লিসা, কয়টা বাজে',
    'লিসা, ব্যাটারি কত',
    'লিসা, ভলিউম বাড়াও',
    'লিসা, সকাল সাতটার অ্যালার্ম দাও',
  ];

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isListening) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant HomePageUpdated oldWidget) {
    super.didUpdateWidget(oldWidget);
    // শোনা শুরু/বন্ধের সাথে পালস অ্যানিমেশন মেলানো
    if (widget.isListening && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isListening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _openHelp() async {
    await HelpCommand.sayHelp(widget.tts, widget.showOverlay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildStatusLine(),
                    const SizedBox(height: 18),
                    _buildMic(),
                    const SizedBox(height: 10),
                    Text(
                      widget.isListening ? 'বলুন…' : 'ট্যাপ করে বলুন',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.speechService.hasError) ...[
                      const SizedBox(height: 12),
                      _buildMicErrorBanner(),
                    ],
                    if (widget.spokenText.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildHeardCard(),
                    ],
                    const SizedBox(height: 22),
                    _buildExamples(),
                    const SizedBox(height: 14),
                    _buildHelpButton(),
                  ],
                ),
              ),
            ),
            LisaBottomNav(
              currentIndex: 0,
              onTap: widget.onPageChanged,
            ),
          ],
        ),
      ),
    );
  }

  // ══ হেডার ══════════════════════════════════════
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF6F7BFF), Color(0xFF4DD8FF)],
            ),
          ),
          child: const Center(
            child: Text(
              'LISA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LISA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'আপনার বাংলা সহকারী',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══ স্টেটাস লাইন ══════════════════════════════
  Widget _buildStatusLine() {
    final listening = widget.isListening;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: listening ? _listenRed.withOpacity(0.12) : _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: listening ? _listenRed.withOpacity(0.55) : _border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            listening ? Icons.graphic_eq : Icons.mic_none,
            color: listening ? _listenRed : _accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              listening
                  ? 'লিসা শুনছে… "লিসা" বলে তারপর কমান্ড বলুন'
                  : 'মাইকে ট্যাপ করে "লিসা" বলে ডাকুন',
              style: TextStyle(
                color: listening ? _listenRed : Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══ বড় মাইক + পালস ════════════════════════════
  Widget _buildMic() {
    return Center(
      child: GestureDetector(
        onTap: widget.onMicTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = widget.isListening ? _pulse.value : 0.0;

            return SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ছড়ানো রিং (শুনছে বোঝাতে)
                  if (widget.isListening)
                    Container(
                      width: 186 + (52 * t),
                      height: 186 + (52 * t),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _listenRed.withOpacity(0.14 - (0.10 * t)),
                      ),
                    ),
                  // বাইরের বর্ডার রিং
                  Container(
                    width: 186,
                    height: 186,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isListening
                            ? _listenRed.withOpacity(0.7)
                            : _border,
                        width: 2,
                      ),
                    ),
                  ),
                  // ভেতরের গোল বাটন
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 138,
                    height: 138,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: widget.isListening
                            ? const [Color(0xFFFF4D4D), Color(0xFFFF8A8A)]
                            : const [Color(0xFF6F7BFF), Color(0xFF4DD8FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isListening ? _listenRed : _accent)
                              .withOpacity(0.45),
                          blurRadius: widget.isListening ? 34 : 20,
                          spreadRadius: widget.isListening ? 6 : 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ══ "লিসা শুনল" কার্ড ═══════════════════════════
  Widget _buildHeardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'লিসা শুনল',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.spokenText,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ══ মাইক সমস্যার ব্যানার ════════════════════════
  Widget _buildMicErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _listenRed.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _listenRed.withOpacity(0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _listenRed, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'মাইক ঠিকভাবে চালু হয়নি। ফোনের সেটিংসে LISA-কে '
              'মাইক্রোফোনের অনুমতি দিন, তারপর অ্যাপ আবার খুলুন।',
              style: TextStyle(color: _listenRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ══ উদাহরণ কমান্ড ══════════════════════════════
  Widget _buildExamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'যেমন বলতে পারেন',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _examples)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  e,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ══ "কী কী পারি?" বোতাম ════════════════════════
  Widget _buildHelpButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _openHelp,
        icon: const Icon(Icons.help_outline, color: _accent, size: 20),
        label: const Text(
          'কী কী পারি?',
          style: TextStyle(color: _accent, fontSize: 15),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: _card,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
