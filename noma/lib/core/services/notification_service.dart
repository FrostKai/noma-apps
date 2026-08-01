import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
    }
  }

  static Future<void> showDailyNightlySummary({
    required double totalExpenseToday,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_summary_channel',
      'Rangkuman Pengeluaran Malam',
      channelDescription: 'Notifikasi rangkuman pengeluaran harian pada malam hari',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    final formattedExpense = 'Rp ${totalExpenseToday.toInt()}';
    final message = totalExpenseToday > 0
        ? 'Malam ini! Kamu sudah mengeluarkan $formattedExpense hari ini. Cek rinciannya di Noma!'
        : 'Malam ini! Belum ada pengeluaran dicatat hari ini. Yuk cek saldo atau catat transaksimu!';

    try {
      await _notificationsPlugin.show(
        1001,
        '🌙 Rangkuman Pengeluaran Malam',
        message,
        platformDetails,
        payload: 'daily_summary',
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }
}
