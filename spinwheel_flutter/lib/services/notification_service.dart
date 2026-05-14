// ============================================================
// services/notification_service.dart
// flutter_local_notifications — notifikasi saat spin selesai
// ============================================================

import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Inisialisasi (dipanggil sekali di main.dart) ──────────────
  Future<void> init() async {
    // Android: ikon notifikasi pakai @mipmap/ic_launcher (default)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(initSettings);

    // Minta permission Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Tampilkan notifikasi hasil spin ──────────────────────────
  Future<void> showSpinResult(String result) async {
    const androidDetails = AndroidNotificationDetails(
      'spin_result_channel',       // channel ID
      'Hasil Spin',                // channel name
      channelDescription: 'Notifikasi saat spin wheel selesai',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'SpinWheel',
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4D96FF),    // warna notifikasi
      enableVibration: true,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      0,                           // notification ID
      '🎯 Hasil Spin',
      '🏆 $result',
      details,
    );
  }

  // ── Cancel semua notifikasi ───────────────────────────────────
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
