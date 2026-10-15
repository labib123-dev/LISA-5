import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/tts_service.dart';
import '../widgets/lisa_bottom_nav.dart';

class SettingsPage extends StatefulWidget {
  final Function(int) onPageChanged;

  /// "Set up check" চাপলে first_run_wizard খুলবে (main.dart থেকে আসবে)
  final VoidCallback? onOpenWizard;

  /// Reset এর পর অ্যাপ আবার শুরু (main.dart থেকে আসবে)
  final VoidCallback? onFactoryReset;

  final TtsService? ttsService;

  const SettingsPage({
    super.key,
    required this.onPageChanged,
    this.onOpenWizard,
    this.onFactoryReset,
    this.ttsService,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _bg = Color(0xFF070722);
  static const _card = Color(0xFF111133);
  static const _border = Color(0xFF2A2A66);
  static const _accent = Color(0xFF6F7BFF);

  bool _vibrationEnabled = true;
  bool _notificationEnabled = true;
  double _ttsSpeed = 0.45;
  double _ttsPitch = 1.0;

  // ⚠️ সব অ্যাপ-ডেটার চাবি একজায়গায় রাখা হলো,
  //    নতুন key যোগ করলে এখানেও যোগ করবে (Reset এটা মুছে দেয়)
  static const List<String> _allKeys = [
    'vibration_enabled',
    'notification_enabled',
    'tts_speed',
    'tts_pitch',
    'setup_done',
    'command_history',
    'wake_word_required',
    'listen_seconds',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _notificationEnabled = prefs.getBool('notification_enabled') ?? true;
      _ttsSpeed = prefs.getDouble('tts_speed') ?? 0.45;
      _ttsPitch = prefs.getDouble('tts_pitch') ?? 1.0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', _vibrationEnabled);
    await prefs.setBool('notification_enabled', _notificationEnabled);
    await prefs.setDouble('tts_speed', _ttsSpeed);
    await prefs.setDouble('tts_pitch', _ttsPitch);
  }

  Future<void> _applyVoiceNow() async {
    await widget.ttsService?.setRate(_ttsSpeed);
    await widget.ttsService?.setPitch(_ttsPitch);
  }

  Future<void> _voiceCheck() async {
    await _applyVoiceNow();
    await widget.ttsService?.stop();
    await widget.ttsService
        ?.speak('আমি লিসা। আপনার কথা শুনে কাজ করতে পারি।');
  }

  Future<void> _confirmReset() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          'Reset app data?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: const Text(
          'This will erase all settings and command history, '
          'and the setup check will run again.\n'
          'This cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );

    if (yes != true) return;

    final prefs = await SharedPreferences.getInstance();
    for (final key in _allKeys) {
      await prefs.remove(key);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: _card,
        content: Text(
          'সব ডেটা মুছে ফেলা হলো। আবার সেটআপ চালু হচ্ছে…',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );

    if (widget.onFactoryReset != null) {
      widget.onFactoryReset!();
    } else {
      widget.onPageChanged(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D2F),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('⚙️ Settings', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('Effects'),
                  _switchTile(
                    'Vibration',
                    _vibrationEnabled,
                    (v) async {
                      setState(() => _vibrationEnabled = v);
                      await _saveSettings();
                    },
                  ),
                  const SizedBox(height: 12),
                  _switchTile(
                    'Notifications',
                    _notificationEnabled,
                    (v) async {
                      setState(() => _notificationEnabled = v);
                      await _saveSettings();
                    },
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle('Voice'),
                  _sliderTile(
                    title: 'Speech Rate',
                    value: _ttsSpeed,
                    min: 0.25,
                    max: 1.0,
                    label: '${(_ttsSpeed * 100).round()}%',
                    onChanged: (v) => setState(() => _ttsSpeed = v),
                    onChangeEnd: (_) async {
                      await _saveSettings();
                      await _applyVoiceNow();
                    },
                  ),
                  const SizedBox(height: 12),
                  _sliderTile(
                    title: 'Voice Tone',
                    value: _ttsPitch,
                    min: 0.5,
                    max: 2.0,
                    label: '${_ttsPitch.toStringAsFixed(1)}x',
                    onChanged: (v) => setState(() => _ttsPitch = v),
                    onChangeEnd: (_) async {
                      await _saveSettings();
                      await _applyVoiceNow();
                    },
                  ),
                  const SizedBox(height: 12),
                  _actionTile(
                    icon: Icons.volume_up_outlined,
                    title: 'Voice check',
                    subtitle: 'Play a sample and check you can hear it',
                    onTap: _voiceCheck,
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle('Setup'),
                  _actionTile(
                    icon: Icons.fact_check_outlined,
                    title: 'Set up check',
                    subtitle:
                        'Check microphone, notifications and Bengali voice again',
                    onTap: () {
                      if (widget.onOpenWizard != null) {
                        widget.onOpenWizard!();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: _card,
                            content: Text(
                              'Setup check এই বিল্ডে যোগ করা হয়নি।',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle('About'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LISA - Personal Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Version: 1.0.0',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'A Bengali voice assistant. Say "লিসা" before every '
                          'command. Works with voice only — no need to hold '
                          'the phone.',
                          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle('Danger zone'),
                  _actionTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Reset app data',
                    subtitle: 'Erase all settings and history',
                    color: const Color(0xFFFF6B6B),
                    onTap: _confirmReset,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
            LisaBottomNav(currentIndex: 2, onTap: widget.onPageChanged),
          ],
        ),
      ),
    );
  }

  // ══ ছোট উইজেট ═════════════════════════════════
  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _accent,
          ),
        ],
      ),
    );
  }

  Widget _sliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required String label,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text(
                label,
                style: const TextStyle(
                  color: _accent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: _accent,
            inactiveColor: Colors.white24,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = _accent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
      ),
    );
  }
}
