import 'package:flutter/material.dart';

/// অ্যাপ চালু হওয়ার সময় দেখানো প্রস্তুতির পর্দা।
/// এখানে ব্যবহারকারী কিছু করতে পারে না — শুধু অপেক্ষা করে।
/// টেক্সট বড় রাখা হলো যাতে চশমা ছাড়াও পড়া যায়।
///
/// পর্ব ৩ — ফাইল ৪/৫
class SplashScreen extends StatelessWidget {
  /// প্রথমবার চালু হলে নিচে সেটআপের বার্তা দেখাবে
  final bool showSetupHint;

  const SplashScreen({super.key, this.showSetupHint = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070722),
      body: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - value)),
                child: child,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ══ লোগো টেক্সট ══
                const Text(
                  'LISA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Personal Assistant',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),

                const SizedBox(height: 44),

                // ══ স্পিনার ══
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                const Text(
                  'শুরু করছি…',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),

                // ══ প্রথমবার হলে সেটআপের বার্তা ══
                if (showSetupHint) ...[
                  const SizedBox(height: 30),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111133),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2A2A66)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.settings_voice_outlined,
                          color: Color(0xFF6F7BFF),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'প্রথমবার চালু হচ্ছে — মাইক ও বাংলা কণ্ঠ সেটআপ চলবে',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
