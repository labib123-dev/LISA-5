// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/feedback_service.dart';
import 'core/speech_service.dart';
import 'core/tts_service.dart';
import 'core/wake_word.dart';
import 'router/command_router.dart';
import 'ui/first_run_wizard.dart';
import 'ui/homepage_updated.dart';
import 'ui/overly_manager.dart';
import 'ui/pages/history_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/splash_screen.dart';

/// LISA v1 — পেজ index:
///   0 = Home      1 = History      2 = Settings      3 = Setup wizard
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LisaApp());
}

class LisaApp extends StatelessWidget {
  const LisaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LISA',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0000),
      ),
      home: const LisaMain(),
    );
  }
}

class LisaMain extends StatefulWidget {
  const LisaMain({super.key});

  @override
  State<LisaMain> createState() => _LisaMainState();
}

class _LisaMainState extends State<LisaMain> {
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();
  final FeedbackService _feedbackService = FeedbackService();

  CommandRouter? _router;

  // ══ ভয়েস ফ্লো সেটিংস (এখানেই বদলাবে) ═══════════
  static const int _firstListenSeconds = 8; // ১ম ধাপ কত সেকেন্ড শুনবে
  static const int _secondListenSeconds = 5; // "বলুন, শুনছি"র পর ৫ সেকেন্ড
  static const bool requireWakeWord = true; // false করলে লিসা ছাড়াও চলবে

  static const int _wizardPage = 3;

  // ══ State ═════════════════════════════════════
  bool _permissionsReady = false;
  bool _isListening = false;
  bool _expectWakeWord = true; // এই ধাপে লিসা বাধ্যতামূলক?
  bool _askedAgain = false; // "বলুন, শুনছি" একবারই বলবে
  bool _commandExecuting = false;
  String _spokenText = ''; // যা শুনেছে / স্ক্রিনে নির্দেশনা
  int _currentPageIndex = 0;

  Timer? _listenTimer;

  final GlobalKey<_OverlayHostState> _overlayKey =
      GlobalKey<_OverlayHostState>();

  void _showOverlay(Widget w) {
    if (_overlayKey.currentState != null) {
      _overlayKey.currentState!.showOverlay(w);
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        _overlayKey.currentState?.showOverlay(w);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _requestPermissions();

      try {
        await _ttsService.init();
      } catch (e) {
        debugPrint('TTS init failed: $e');
      }

      try {
        await _speechService.initialize();
      } catch (e) {
        debugPrint('Speech init failed: $e');
      }

      // প্যাচ ৬: init() এখন Settings-এর vibration/notification সুইচও পড়ে
      try {
        await _feedbackService.init();
      } catch (e) {
        debugPrint('Feedback init failed: $e');
      }

      _router = CommandRouter(
        tts: _ttsService.engine,
        showOverlay: _showOverlay,
      );

      // প্যাচ ২: প্রথমবার হলে সেটআপ উইজার্ডে পাঠাও
      try {
        final prefs = await SharedPreferences.getInstance();
        final setupDone = prefs.getBool('setup_done') ?? false;
        if (!setupDone) _currentPageIndex = _wizardPage;
      } catch (e) {
        debugPrint('Setup check failed: $e');
      }

      if (mounted) setState(() => _permissionsReady = true);
    } catch (e) {
      debugPrint('LISA init error: $e');
      if (mounted) setState(() => _permissionsReady = true);
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.microphone,
      Permission.notification,
    ].request();

    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    if (!micGranted) debugPrint('Microphone permission not granted.');
  }

  // ══ মাইক বাটন ═════════════════════════════════
  Future<void> _onMicTap() async {
    if (_commandExecuting) return;

    if (_isListening) {
      await _stopListening('থামানো হলো। ট্যাপ করে আবার বলুন।');
      return;
    }

    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        await _ttsService.speak('মাইক্রোফোনের অনুমতি ছাড়া শোনা সম্ভব নয়।');
        return;
      }
    }

    _askedAgain = false;
    await _startListening(
      seconds: _firstListenSeconds,
      expectWakeWord: requireWakeWord,
    );
  }

  // ══ শোনা শুরু ═════════════════════════════════
  Future<void> _startListening({
    required int seconds,
    required bool expectWakeWord,
  }) async {
    if (_commandExecuting) return;

    final ready = await _speechService.initialize();
    if (!ready) {
      await _ttsService.speak('মাইক্রোফোন চালু করা যায়নি।');
      if (mounted) setState(() => _isListening = false);
      return;
    }

    // LISA নিজের কথা যেন নিজে না শোনে
    await _ttsService.stop();

    if (mounted) {
      setState(() {
        _isListening = true;
        _expectWakeWord = expectWakeWord;
        _spokenText = '';
      });
    }

    await _feedbackService.onListeningStarted();

    // STT নিজে থামলেও নির্দিষ্ট সময়ে জোর করে থামানোর জন্য
    _listenTimer?.cancel();
    _listenTimer = Timer(
      Duration(milliseconds: seconds * 1000 + 800),
      _onWindowExpired,
    );

    try {
      await _speechService.startListening(
        listenFor: Duration(seconds: seconds),
        pauseFor: const Duration(seconds: 2),
        onResult: _handleSpeechResult,
      );
    } catch (e) {
      debugPrint('Listen error: $e');
      _listenTimer?.cancel();
      if (mounted) setState(() => _isListening = false);
    }
  }

  // ══ STT ফলাফল ═════════════════════════════════
  Future<void> _handleSpeechResult(String text, bool isFinal) async {
    if (!mounted) return;

    final clean = text.trim();

    // স্ক্রিনে সাথে সাথে দেখাও — partial হলেও
    if (clean.isNotEmpty && _isListening) {
      setState(() => _spokenText = clean);
    }

    if (!isFinal) return; // partial হলে কিছুই করব না (মূল বাগ ফিক্স)
    if (_commandExecuting) return;

    _listenTimer?.cancel();
    _listenTimer = null;

    await _handleFinalSpeech(clean);
  }

  Future<void> _handleFinalSpeech(String text) async {
    if (text.isEmpty) {
      await _handleNoCommand();
      return;
    }

    final hasWakeWord = WakeWord.detected(text);
    String command;

    if (hasWakeWord) {
      command = WakeWord.extractCommand(text).trim();
    } else if (_expectWakeWord) {
      // লিসা না বলে কথা বলা হয়েছে
      await _stopListening(null);
      await _ttsService.speak('মনে রাখবেন, আগে লিসা বলে ডাকবেন।');
      return;
    } else {
      // "বলুন, শুনছি"র পর — লিসা ছাড়াই কমান্ড নেওয়া হবে
      command = text;
    }

    if (command.isEmpty) {
      await _handleNoCommand();
      return;
    }

    await _executeCommand(text, command);
  }

  // ══ কমান্ড না পেলে ════════════════════════════
  Future<void> _handleNoCommand() async {
    // ধাপ ১: একবার "বলুন, শুনছি" বলে ৫ সেকেন্ড শোনা
    if (!_askedAgain) {
      _askedAgain = true;
      await _stopListening('শুনতে পাইনি…');
      await _ttsService.speak('বলুন, শুনছি।');
      if (!mounted) return;
      await _startListening(
        seconds: _secondListenSeconds,
        expectWakeWord: false,
      );
      return;
    }

    // ধাপ ২: দুইবারও কিছু নেই → মাইক বন্ধ (ইউজার ট্যাপ করলে আবার চালু)
    _askedAgain = false;
    await _stopListening('শুনতে পাইনি। ট্যাপ করে আবার বলুন।');
  }

  // ══ কমান্ড চালানো ═════════════════════════════
  Future<void> _executeCommand(String originalText, String command) async {
    if (_router == null) {
      await _ttsService.speak('LISA এখনো প্রস্তুত হয়নি। একটু পরে বলুন।');
      await _stopListening(null);
      return;
    }

    _listenTimer?.cancel();
    _listenTimer = null;

    if (mounted) {
      setState(() {
        _commandExecuting = true;
        _isListening = false;
        _askedAgain = false;
        _spokenText = originalText;
      });
    }

    await _speechService.stopListening();
    await _feedbackService.onProcessing();

    try {
      final result = await _router!.route(command);

      await _saveToHistory(
        originalText,
        command,
        result.success,
        result.message,
      );

      if (result.success) {
        await _feedbackService.onCommandSuccess(result.message);
      } else {
        await _feedbackService.onCommandFailed(result.message);
      }
    } catch (e) {
      debugPrint('Route error: $e');
      await _ttsService.speak('দুঃখিত, কিছু একটা সমস্যা হয়েছে।');
    } finally {
      if (mounted) setState(() => _commandExecuting = false);
    }
  }

  // ══ শোনা বন্ধ ═════════════════════════════════
  Future<void> _stopListening([String? screenHint]) async {
    _listenTimer?.cancel();
    _listenTimer = null;

    if (_speechService.isListening) {
      await _speechService.stopListening();
    }
    await _feedbackService.clearFeedback();

    if (mounted) {
      setState(() {
        _isListening = false;
        if (screenHint != null) _spokenText = screenHint;
      });
    }
  }

  void _onWindowExpired() {
    if (_commandExecuting) return;
    _handleNoCommand();
  }

  // ══ ইতিহাস ════════════════════════════════════
  Future<void> _saveToHistory(
    String heard,
    String command,
    bool success,
    String message,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('command_history') ?? [];
      final timestamp = DateTime.now().toString().split('.')[0];
      history.insert(
        0,
        '${success ? 'success' : 'failed'}|$command|$message|$timestamp',
      );
      if (history.length > 30) history.removeAt(30);
      await prefs.setStringList('command_history', history);
    } catch (e) {
      debugPrint('History save error: $e');
    }
  }

  // ══ পেজ বদল ═══════════════════════════════════
  void _onPageChanged(int index) {
    // প্যাচ ৬: Settings-এ সুইচ বদলে ফিরে এলে নতুন পছন্দ সাথে সাথে লাগু হবে
    _feedbackService.reloadSettings();

    if (mounted) setState(() => _currentPageIndex = index);
  }

  @override
  void dispose() {
    _listenTimer?.cancel();
    _speechService.stopListening();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionsReady) return const SplashScreen();

    return PopScope(
      canPop: _currentPageIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // প্যাচ ৫: সেটআপ উইজার্ড চলাকালীন পিছনে চাপলে কিছুই হবে না
        if (_currentPageIndex == _wizardPage) return;

        setState(() => _currentPageIndex = 0);
      },
      child: _OverlayHost(
        key: _overlayKey,
        child: Scaffold(body: _buildPage()),
      ),
    );
  }

  Widget _buildPage() {
    switch (_currentPageIndex) {
      case 0:
        return HomePageUpdated(
          isListening: _isListening,
          spokenText: _spokenText,
          onMicTap: _onMicTap,
          tts: _ttsService.engine,
          speechService: _speechService,
          onPageChanged: _onPageChanged,
          showOverlay: _showOverlay,
        );

      case 1:
        return HistoryPage(onPageChanged: _onPageChanged);

      case 2:
        // প্যাচ ৪: Settings-এর সব বোতাম/স্লাইডার এখন সত্যিই কাজ করবে
        return SettingsPage(
          onPageChanged: _onPageChanged,
          ttsService: _ttsService,
          onOpenWizard: () =>
              setState(() => _currentPageIndex = _wizardPage),
          onFactoryReset: () async {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('setup_done', false);
            } catch (e) {
              debugPrint('Factory reset flag error: $e');
            }
            if (!mounted) return;
            setState(() {
              _spokenText = '';
              _currentPageIndex = _wizardPage;
            });
          },
        );

      // প্যাচ ৩: সেটআপ উইজার্ড
      case 3:
        return FirstRunWizard(
          ttsService: _ttsService,
          speechService: _speechService,
          onComplete: () {
            if (!mounted) return;
            setState(() {
              _spokenText = 'মাইকে ট্যাপ করে লিসা বলে ডাকুন।';
              _currentPageIndex = 0;
            });
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _OverlayHost extends StatefulWidget {
  const _OverlayHost({super.key, required this.child});

  final Widget child;

  @override
  State<_OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<_OverlayHost> {
  Widget? _overlayWidget;

  void showOverlay(Widget w) => setState(() => _overlayWidget = w);
  void hideOverlay() => setState(() => _overlayWidget = null);

  @override
  Widget build(BuildContext context) {
    return OverlayManager(
      overlayWidget: _overlayWidget,
      onDismiss: hideOverlay,
      child: widget.child,
    );
  }
}
