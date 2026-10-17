import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/speech_service.dart';
import '../core/tts_service.dart';

/// প্রথমবার চালু হলে যাবতীয় রিকোয়ারমেন্ট চেক করার উইজার্ড।
/// Settings থেকে "Set up check" চাপলেও এই একই স্ক্রিন খোলে
/// (তখন isRecheck: true পাঠাতে হবে)।
///
/// ⚠️ "শুরু করুন" চাপলে সব পাস হলেই হোমে যাবে,
///    একটাও বাকি থাকলে warning দেখিয়ে কী কী বাকি তা বলবে।
///
/// 🔧 বাগ ৩ ফিক্স:
///   আগে "পরে করব" বোতামটা Navigator.pop() করত, কিন্তু উইজার্ড
///   কোনো route-এ push করা নয় (main.dart-এর ভেতরে সরাসরি widget)।
///   তাই চাপলে কিছুই হতো না → ইউজার আটকে যেত।
///   এখন onSkip callback দিয়ে main.dart হোমে ফেরায়।
class FirstRunWizard extends StatefulWidget {
  final TtsService ttsService;
  final SpeechService speechService;

  /// সব চেক পাস হলে কল হবে (main.dart হোমে পাঠাবে)
  final VoidCallback onComplete;

  /// true হলে Settings থেকে খোলা হয়েছে → "পরে করব" বোতাম দেখাবে
  final bool isRecheck;

  /// 🔧 "পরে করব" চাপলে কল হবে (main.dart হোমে পাঠাবে)
  final VoidCallback? onSkip;

  const FirstRunWizard({
    super.key,
    required this.ttsService,
    required this.speechService,
    required this.onComplete,
    this.isRecheck = false,
    this.onSkip,
  });

  @override
  State<FirstRunWizard> createState() => _FirstRunWizardState();
}

class _FirstRunWizardState extends State<FirstRunWizard>
    with WidgetsBindingObserver {
  static const _bg = Color(0xFF070722);
  static const _card = Color(0xFF111133);
  static const _border = Color(0xFF2A2A66);
  static const _accent = Color(0xFF6F7BFF);

  int _step = 0;
  static const int _lastStep = 5;

  // ── চেকের ফলাফল ───────────────────────────────
  bool _micPermission = false;
  bool _notificationOk = true; // Android 13 এর নিচে দরকার নেই
  bool _ttsEngine = false;
  bool _ttsBengali = false;
  bool _ttsHeard = false;
  bool _ttsSkipped = false;
  bool _sttBengali = false;

  // ── মাইক টেস্ট ────────────────────────────────
  bool _testing = false;
  bool _micTestPassed = false;
  String _micTestText = '';
  Timer? _testTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAll();
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // কণ্ঠ ইনস্টল বা সেটিংস থেকে ফিরে এলে আবার চেক
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  // ══ সব চেক আবার চালাও ══════════════════════════
  Future<void> _refreshAll() async {
    await _checkMic();
    await _checkNotification();
    await _checkTts();
    _checkStt();
    if (mounted) setState(() {});
  }

  Future<void> _checkMic() async {
    final status = await Permission.microphone.status;
    _micPermission = status.isGranted;
  }

  Future<void> _checkNotification() async {
    final status = await Permission.notification.status;
    _notificationOk = status.isGranted || status.isLimited;
  }

  Future<void> _checkTts() async {
    try {
      await widget.ttsService.init();
      _ttsEngine = true;
      _ttsBengali = widget.ttsService.bengaliAvailable;
    } catch (e) {
      debugPrint('TTS check error: $e');
      _ttsEngine = false;
      _ttsBengali = false;
    }
  }

  void _checkStt() {
    _sttBengali = widget.speechService.localeId.startsWith('bn');
  }

  /// সব বাধ্যতামূলক চেক পাস?
  bool get _allDone =>
      _micPermission && _notificationOk && _ttsBengali && _ttsHeard && _micTestPassed;

  // ══ ধাপ ১: মাইক পারমিশন ═════════════════════════
  Future<void> _askMic() async {
    final result = await Permission.microphone.request();
    _micPermission = result.isGranted;
    if (!mounted) return;
    setState(() {});

    if (!_micPermission) {
      await widget.ttsService
          .speak('মাইক্রোফোনের অনুমতি না দিলে আমি শুনতে পারব না।');
    }
  }

  // ══ ধাপ ২: নোটিফিকেশন ══════════════════════════
  Future<void> _askNotification() async {
    final result = await Permission.notification.request();
    _notificationOk = result.isGranted || result.isLimited;
    if (!mounted) return;
    setState(() {});
  }

  // ══ ধাপ ৩: বাংলা কণ্ঠ ══════════════════════════
  Future<void> _installVoice() async {
    try {
      const intent = AndroidIntent(
        action: 'android.speech.tts.engine.INSTALL_TTS_DATA',
      );
      await intent.launch();
    } catch (e) {
      debugPrint('Install TTS intent failed: $e');
    }
  }

  Future<void> _hearSample() async {
    await widget.ttsService.stop();
    await widget.ttsService.speak('আমি লিসা। আপনার কথা শুনে কাজ করতে পারি।');
  }

  // ══ ধাপ ৪: লাইভ মাইক টেস্ট ═════════════════════
  Future<void> _startMicTest() async {
    if (_testing) return;

    final ready = await widget.speechService.initialize();
    if (!ready) {
      if (mounted) {
        setState(() => _micTestText = 'মাইক্রোফোন চালু করা যায়নি।');
      }
      return;
    }

    // LISA নিজের কথা যেন নিজে না শোনে
    await widget.ttsService.stop();

    setState(() {
      _testing = true;
      _micTestPassed = false;
      _micTestText = '';
    });

    _testTimer?.cancel();
    // ৫ সেকেন্ড শোনা + ১ সেকেন্ড বাড়তি হিসাব
    _testTimer = Timer(const Duration(seconds: 6), _endMicTest);

    try {
      await widget.speechService.startListening(
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 2),
        onResult: (text, isFinal) {
          final clean = text.trim();

          if (clean.isNotEmpty && mounted) {
            setState(() => _micTestText = clean);
          }

          if (isFinal) {
            _endMicTest(passed: clean.isNotEmpty);
          }
        },
      );
    } catch (e) {
      debugPrint('Mic test error: $e');
      _endMicTest();
    }
  }

  void _endMicTest({bool? passed}) {
    _testTimer?.cancel();
    _testTimer = null;
    widget.speechService.stopListening();

    if (!mounted) return;
    setState(() {
      _testing = false;
      if (passed != null) _micTestPassed = passed;
      if (_micTestText.isEmpty) _micTestText = 'কিছু শুনতে পাইনি।';
    });
  }

  // ══ "শুরু করুন" চাপা ═══════════════════════════
  Future<void> _finish() async {
    await _refreshAll();

    if (_allDone) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setup_done', true);
      if (!mounted) return;
      widget.onComplete();
      return;
    }

    final missing = [
      if (!_micPermission) 'মাইক্রোফোনের অনুমতি দেওয়া হয়নি',
      if (!_notificationOk) 'নোটিফিকেশনের অনুমতি দেওয়া হয়নি',
      if (!_ttsBengali) 'বাংলা কণ্ঠ ইনস্টল করা হয়নি',
      if (!_ttsHeard) 'কণ্ঠ পরীক্ষা করে "হ্যাঁ, শুনেছি" চাপা হয়নি',
      if (!_micTestPassed) 'মাইক টেস্ট পাস হয়নি',
    ];

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          'এখনো বাকি আছে',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'নিচের কাজগুলো শেষ করলে LISA ঠিকভাবে কাজ করবে:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            for (final m in missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $m',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          // 🔧 বাগ ৩ ফিক্স: Navigator.pop() বাদ → onSkip callback
          if (widget.isRecheck)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (widget.onSkip != null) {
                  widget.onSkip!();
                }
              },
              child: const Text('পরে করব'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _step = 1);
            },
            child: const Text('আবার চেক করি'),
          ),
        ],
      ),
    );
  }

  // ══ UI ═════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgress(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _buildStep(),
              ),
            ),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Text(
            'ধাপ ${_step + 1} / $_lastStep',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_step + 1) / _lastStep,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(_accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _stepWelcome();
      case 1:
        return _stepMic();
      case 2:
        return _stepNotification();
      case 3:
        return _stepTts();
      case 4:
        return _stepMicTest();
      default:
        return _stepFinish();
    }
  }

  // ধাপ ০ — স্বাগতম
  Widget _stepWelcome() {
    return _stepBody(
      emoji: '👋',
      title: 'স্বাগতম',
      desc: 'আমি লিসা — আপনার বাংলা ভয়েস সহকারী।\n'
          'ফোনে হাত না দিয়েই শুধু কথা বলে কাজ করাতে পারবেন।\n\n'
          'শুরুর আগে ৩টা নিয়ম:\n'
          '১) প্রতিটি কথা বলার আগে "লিসা" বলে ডাকবেন\n'
          '২) পরিষ্কার করে, একটু জোরে বলবেন\n'
          '৩) মাইক বাটনে ট্যাপ করে শোনা শুরু হবে',
    );
  }

  // ধাপ ১ — মাইক পারমিশন
  Widget _stepMic() {
    return _stepBody(
      emoji: '🎤',
      title: 'মাইক্রোফোনের অনুমতি',
      desc: 'আপনার কথা শোনার জন্য মাইক্রোফোনের অনুমতি দরকার। '
          'এই অনুমতি ছাড়া আমি কিছুই শুনতে পারব না।',
      child: Column(
        children: [
          _statusRow('মাইক্রোফোনের অনুমতি', _micPermission),
          const SizedBox(height: 16),
          _bigButton(
            label: _micPermission ? 'ঠিক আছে ✓' : 'অনুমতি দিন',
            enabled: !_micPermission,
            onTap: _askMic,
          ),
          if (!_micPermission)
            TextButton(
              onPressed: openAppSettings,
              child: const Text(
                'ফোনের সেটিংস খুলুন',
                style: TextStyle(color: _accent, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }

  // ধাপ ২ — নোটিফিকেশন
  Widget _stepNotification() {
    return _stepBody(
      emoji: '🔔',
      title: 'নোটিফিকেশনের অনুমতি',
      desc: 'কমান্ড কাজ হলে ছোট একটা জানানো আসবে — '
          'এতে আপনি বুঝবেন LISA ঠিকমতো শুনেছে কি না।\n'
          'এটা না দিলেও কাজ চলবে, তবে কোনো জানানো পাবেন না।',
      child: Column(
        children: [
          _statusRow('নোটিফিকেশন', _notificationOk),
          const SizedBox(height: 16),
          _bigButton(
            label: _notificationOk ? 'ঠিক আছে ✓' : 'অনুমতি দিন',
            enabled: !_notificationOk,
            onTap: _askNotification,
          ),
        ],
      ),
    );
  }

  // ধাপ ৩ — বাংলা কণ্ঠ (TTS)
  Widget _stepTts() {
    return _stepBody(
      emoji: '🔊',
      title: 'বাংলা কণ্ঠ',
      desc: 'আমি বাংলায় কথা বলব — তার জন্য ফোনে বাংলা কণ্ঠ ইনস্টল থাকা দরকার। '
          'নিচের বোতামে চাপলে ফোন নিজেই কণ্ঠ ডাউনলোডের পর্দা খুলে দেবে। '
          'ডাউনলোড শেষ করে আবার এই অ্যাপে ফিরে আসুন — আমি নিজেই চেক করব।',
      child: Column(
        children: [
          _statusRow('কণ্ঠ ইনজিন', _ttsEngine),
          _statusRow('বাংলা কণ্ঠ', _ttsBengali),
          _statusRow('নমুনা শোনা হয়েছে', _ttsHeard),
          const SizedBox(height: 12),

          if (!_ttsBengali)
            _bigButton(label: 'কণ্ঠ ইনস্টল করুন', onTap: _installVoice),

          if (_ttsBengali) ...[
            _bigButton(label: 'নমুনা শুনুন', onTap: _hearSample),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _bigButton(
                    label: 'হ্যাঁ, শুনেছি',
                    color: const Color(0xFF1F7A3D),
                    onTap: () => setState(() => _ttsHeard = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _bigButton(
                    label: 'শুনতে পাইনি',
                    color: const Color(0xFF7A1F1F),
                    onTap: () => setState(() => _ttsHeard = false),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _ttsSkipped = true;
              _step = 4;
            }),
            child: const Text(
              'এখনই সেট করব না — পরে করব',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ধাপ ৪ — লাইভ মাইক টেস্ট
  Widget _stepMicTest() {
    return _stepBody(
      emoji: '🗣️',
      title: 'মাইক পরীক্ষা',
      desc: 'এবার বলুন — "লিসা, কয়টা বাজে"।\n'
          'চাপ দিলে ৫ সেকেন্ড শুনব। আমি যা বুঝেছি নিচে দেখাব।',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Text(
              _micTestText.isEmpty
                  ? (_testing ? 'শুনছি… এখন বলুন।' : 'এখনো পরীক্ষা করা হয়নি।')
                  : _micTestText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          _statusRow('মাইক পরীক্ষা', _micTestPassed),
          const SizedBox(height: 12),
          _bigButton(
            label: _testing ? 'শুনছি…' : 'পরীক্ষা শুরু করুন',
            enabled: !_testing,
            onTap: _startMicTest,
          ),
        ],
      ),
    );
  }

  // ধাপ ৫ — শেষ
  Widget _stepFinish() {
    return _stepBody(
      emoji: _allDone ? '✅' : '⚠️',
      title: _allDone ? 'সব প্রস্তুত' : 'কিছু জিনিস বাকি',
      desc: _allDone
          ? 'সব ঠিকঠাক হয়েছে। এখন "শুরু করুন" চাপুন, '
              'তারপর মাইক বাটনে ট্যাপ করে "লিসা" বলে ডাকুন।'
          : 'নিচের যেগুলো লাল দেখাচ্ছে, সেগুলো আগে ঠিক করতে হবে। '
              '"শুরু করুন" চাপলে আমি আবার যাচাই করে দেখব।',
      child: Column(
        children: [
          _statusRow('মাইক্রোফোনের অনুমতি', _micPermission),
          _statusRow('নোটিফিকেশন', _notificationOk),
          _statusRow('বাংলা কণ্ঠ', _ttsBengali),
          _statusRow('কণ্ঠ শুনে যাচাই', _ttsHeard),
          _statusRow('মাইক পরীক্ষা', _micTestPassed),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(
                  _sttBengali ? Icons.check_circle : Icons.info_outline,
                  color: _sttBengali ? Colors.greenAccent : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _sttBengali
                        ? 'বাংলা ভাষা চেনা যাচ্ছে (${widget.speechService.localeId})'
                        : 'বাংলা ভাষা পাওয়া যায়নি — ফোনের Google/Speech সেটিংস থেকে বাংলা যোগ করুন',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_ttsSkipped && _ttsBengali)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'কণ্ঠ ঠিক আছে — তবে নমুনা শুনে যাচাই করাই ভালো।',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  // ══ নিচের বোতাম ═══════════════════════════════
  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: _bigButton(
                label: 'পিছনে',
                color: const Color(0xFF22224A),
                onTap: () => setState(() => _step--),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            child: _bigButton(
              label: _step == _lastStep ? 'শুরু করুন' : 'পরের ধাপ',
              onTap: _step == _lastStep
                  ? _finish
                  : () => setState(() => _step++),
            ),
          ),
        ],
      ),
    );
  }

  // ══ ছোট সাহায্যকারী উইজেট ═════════════════════
  Widget _stepBody({
    required String emoji,
    required String title,
    required String desc,
    Widget? child,
  }) {
    return ListView(
      children: [
        const SizedBox(height: 8),
        Text(emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          desc,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        if (child != null) child,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _statusRow(String label, bool ok) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            color: ok ? Colors.greenAccent : const Color(0xFFFF6B6B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    Color color = _accent,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: const Color(0xFF1B1B3A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
