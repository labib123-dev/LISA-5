import 'package:flutter/material.dart';

// সব page এ একই bottom navigation দেখানোর জন্য shared widget।
// এটা Notes, History, Settings সব page এ use করা হবে যাতে
// যেকোনো page থেকে Home বা অন্য page এ যাওয়া যায়।
class LisaBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const LisaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected
                ? const Color(0xFF6F7BFF)
                : Colors.white54,
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF6F7BFF)
                  : Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
