import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/lisa_bottom_nav.dart';

/// History পেজ — LISA কী শুনল আর কী উত্তর দিল, তার তালিকা।
///
/// Storage: 'command_history' List<String>
/// ফরম্যাট: 'success|command|message|timestamp'
///   success|failed = status
///   command        = user যা বলেছিল (বাংলা টেক্সট, হুবহু)
///   message        = LISA-র উত্তর (বাংলা টেক্সট)
///   timestamp      = DateTime().toString()
///
/// পর্ব ৩ — ফাইল ৩/৫
class HistoryPage extends StatefulWidget {
  final Function(int) onPageChanged;

  const HistoryPage({
    super.key,
    required this.onPageChanged,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _bg = Color(0xFF070722);
  static const _card = Color(0xFF111133);
  static const _border = Color(0xFF2A2A66);
  static const _accent = Color(0xFF6F7BFF);

  // হাইলাইট রঙ — success সবুজ, failed লাল
  static const _okBg = Color(0xFF12351F);
  static const _okBorder = Color(0xFF2E7D4F);
  static const _okText = Color(0xFF9BE7B8);

  static const _failBg = Color(0xFF3A1518);
  static const _failBorder = Color(0xFF8E2F35);
  static const _failText = Color(0xFFFFA8A8);

  /// সর্বোচ্চ কতটা এন্ট্রি রাখা হবে (main.dart-এর সীমার সাথে মিলবে)
  static const int maxEntries = 30;

  List<Map<String, dynamic>> _history = [];
  int _successCount = 0;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('command_history') ?? [];

    final history = <Map<String, dynamic>>[];
    int success = 0;
    int failed = 0;

    for (final entry in stored) {
      final parts = entry.split('|');
      if (parts.length < 3) continue;

      final isSuccess = parts[0] == 'success';

      history.add({
        'success': isSuccess,
        'command': parts[1],
        'message': parts[2],
        'time': parts.length > 3 ? parts[3] : '',
      });

      if (isSuccess) {
        success++;
      } else {
        failed++;
      }

      // পুরনো ডেটাতেও সীমা মানা হবে
      if (history.length >= maxEntries) break;
    }

    if (!mounted) return;
    setState(() {
      _history = history;
      _successCount = success;
      _failedCount = failed;
    });
  }

  // ══ ইতিহাস মুছে ফেলা ═══════════════════════════
  Future<void> _confirmClear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          'Clear history?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: const Text(
          'All saved commands will be deleted. This cannot be undone.',
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
              'Clear',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );

    if (yes != true) return;
    await _clearHistory();
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('command_history');

    if (!mounted) return;
    setState(() {
      _history = [];
      _successCount = 0;
      _failedCount = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: _card,
        content: Text(
          'History cleared.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // ══ UI ═════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D2F),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('📊 History', style: TextStyle(color: Colors.white)),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: _accent,
                backgroundColor: _card,
                onRefresh: _loadHistory,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCounters(),
                    const SizedBox(height: 16),
                    if (_history.isEmpty)
                      _buildEmpty()
                    else
                      for (final item in _history) _buildItem(item),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            LisaBottomNav(currentIndex: 1, onTap: widget.onPageChanged),
          ],
        ),
      ),
    );
  }

  // ══ উপরের কাউন্টার ═════════════════════════════
  Widget _buildCounters() {
    return Row(
      children: [
        Expanded(
          child: _counterBox(
            label: 'Success',
            value: _successCount,
            color: _okText,
            border: _okBorder,
            bg: _okBg,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _counterBox(
            label: 'Failed',
            value: _failedCount,
            color: _failText,
            border: _failBorder,
            bg: _failBg,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _counterBox(
            label: 'Total',
            value: _history.length,
            color: Colors.white,
            border: _border,
            bg: _card,
          ),
        ),
      ],
    );
  }

  Widget _counterBox({
    required String label,
    required int value,
    required Color color,
    required Color border,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ══ একটা এন্ট্রি কার্ড ═════════════════════════
  Widget _buildItem(Map<String, dynamic> item) {
    final isSuccess = item['success'] == true;
    final command = (item['command'] ?? '').toString();
    final message = (item['message'] ?? '').toString();
    final time = (item['time'] ?? '').toString();

    final bg = isSuccess ? _okBg : _failBg;
    final border = isSuccess ? _okBorder : _failBorder;
    final textColor = isSuccess ? _okText : _failText;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: status + time ────────────────
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.cancel,
                color: textColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isSuccess ? 'Success' : 'Failed',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── User (কী বলেছিল) ─────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person_outline, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  command.isEmpty ? '—' : command,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── LISA-র উত্তর — হাইলাইটেড bubble ──────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mic_none, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    message.isEmpty ? '—' : message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══ খালি অবস্থা ════════════════════════════════
  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.history, color: Colors.white24, size: 44),
          const SizedBox(height: 14),
          const Text(
            'No commands yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Go to Home, tap the mic and say "লিসা, টর্চ জ্বালাও".\n'
            'Every command will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => widget.onPageChanged(0),
            child: const Text(
              'Go to Home',
              style: TextStyle(color: _accent, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
