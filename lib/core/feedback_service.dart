// lib/core/feedback_service.dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// FeedbackService — wake word ধরা পড়লে বা LISA respond করার সময়
/// notification ও vibration দিয়ে visual/haptic feedback দেয়।
/// কোনো special permission (overlay) ছাড়াই কাজ করে, সব Android
/// version এ নিরাপদে চলে।
///
/// ⚠️ প্যাচ: এখন Settings-এর দুই সুইচ মানা হয় —
///     vibration_enabled    → কম্পন চালু/বন্ধ
///     notification_enabled → নোটিফিকেশন চালু/বন্ধ
/// Settings-এ সুইচ বদলানোর পরে `reloadSettings()` কল করতে হবে।
class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// নোটিফিকেশন প্লাগিন একবারই init হবে
  bool _pluginReady = false;

  /// Settings থেকে পড়া ইউজারের পছন্দ
  bool _vibrationEnabled = true;
  bool _notificationEnabled = true;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get notificationEnabled => _notificationEnabled;

  // একটা ধারাবাহিক notification id ব্যবহার করা হচ্ছে, যাতে প্রতিটা
  // command এ notification bar এ নতুন নতুন entry না জমে, বরং
  // একই notification আপডেট হয়।
  static const int _notificationId = 1001;

  /// অ্যাপ চালু হয়ে একবার কল হবে (main.dart থেকে)
  Future<void> init() async {
    await reloadSettings();
    await _ensurePlugin();
  }

  /// ── Settings-এর সুইচ আবার পড়া ──
  /// Settings পেজ থেকে ফেরার পরে (বা সুইচ বদলানোর পরে) কল করবে।
  /// প্লাগিন আবার init হয় না, তাই দ্রুত ও নিরাপদ।
  Future<void> reloadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _notificationEnabled = prefs.getBool('notification_enabled') ?? true;
    } catch (e) {
      debugPrint('Feedback settings load error: $e');
      _vibrationEnabled = true;
      _notificationEnabled = true;
    }

    // নোটিফিকেশন বন্ধ করলে পুরনো notification-টাও সরিয়ে দাও
    if (!_notificationEnabled) {
      try {
        await _notifications.cancel(_notificationId);
      } catch (_) {}
    }

    debugPrint(
      'Feedback → vibration: $_vibrationEnabled, '
      'notification: $_notificationEnabled',
    );
  }

  /// ── নোটিফিকেশন প্লাগিন (একবারই) ──
  Future<void> _ensurePlugin() async {
    if (_pluginReady) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    // Android 8.0+ এ notification channel তৈরি করা আবশ্যক,
    // নাহলে notification দেখানো যায় না।
    const channel = AndroidNotificationChannel(
      'lisa_feedback_channel',
      'LISA Voice Feedback',
      description:
          'LISA শোনা শুরু করলে বা কোনো কমান্ড সম্পন্ন করলে এই চ্যানেলে নোটিফিকেশন আসে।',
      importance: Importance.high,
      playSound: false,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);

    _pluginReady = true;
  }

  // LISA শোনা শুরু করলে call করা হবে।
  Future<void> onListeningStarted() async {
    await _showNotification(
      title: 'LISA শুনছে...',
      body: 'বলুন, আমি শুনছি।',
    );

    await _vibrate(pattern: [0, 80]);
  }

  // LISA একটা command বুঝে process করার সময় call করা হবে।
  Future<void> onProcessing() async {
    await _showNotification(
      title: 'LISA',
      body: 'বুঝার চেষ্টা করছি...',
    );

    await _vibrate(pattern: [0, 40, 60, 40]);
  }

  // LISA সফলভাবে একটা command সম্পন্ন করলে call করা হবে।
  Future<void> onCommandSuccess(String message) async {
    await _showNotification(
      title: 'LISA সম্পন্ন করেছে',
      body: message,
    );

    await _vibrate(pattern: [0, 60, 50, 60]);
  }

  // কোনো error/fail হলে call করা হবে।
  Future<void> onCommandFailed(String message) async {
    await _showNotification(
      title: 'LISA',
      body: message,
    );

    await _vibrate(pattern: [0, 150]);
  }

  // শোনা বন্ধ হলে notification সরিয়ে দেওয়ার জন্য।
  Future<void> clearFeedback() async {
    try {
      await _notifications.cancel(_notificationId);
    } catch (_) {}
  }

  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    // ইউজার নোটিফিকেশন বন্ধ করে দিলে কিছুই দেখানো হবে না
    if (!_notificationEnabled) return;

    await _ensurePlugin();

    const androidDetails = AndroidNotificationDetails(
      'lisa_feedback_channel',
      'LISA Voice Feedback',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF7B2FF7),
      playSound: false,
      // কম্পন আমরা নিজেরাই Vibration প্যাকেজ দিয়ে করি
      enableVibration: false,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.show(_notificationId, title, body, details);
    } catch (e) {
      debugPrint('Notification show error: $e');
    }
  }

  Future<void> _vibrate({required List<int> pattern}) async {
    // ইউজার কম্পন বন্ধ করে দিলে কিছুই হবে না
    if (!_vibrationEnabled) return;

    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(pattern: pattern);
      }
    } catch (_) {
      // vibration না থাকলেও app চলবে।
    }
  }
}
