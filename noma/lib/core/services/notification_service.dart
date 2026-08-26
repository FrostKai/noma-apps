import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../constants/app_routes.dart';
import '../router/app_router.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int dailyReminderId = 1001;
  static const String _dailyReminderPayload = 'daily_reminder_add_transaction';

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification clicked: ${details.payload}');
          if (details.payload == _dailyReminderPayload) {
            appRouter.go(AppRoutes.addTransaction);
          }
        },
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
    }
  }

  static String _formatRupiah(double amount) {
    final intVal = amount.toInt();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  static Future<void> showDailyNightlySummary({
    required double totalExpenseToday,
  }) async {
    const platformDetails = NotificationDetails(android: _androidDetails);

    final formattedExpense = _formatRupiah(totalExpenseToday);
    final message = totalExpenseToday > 0
        ? 'Malam ini! Kamu sudah mengeluarkan $formattedExpense hari ini. Cek rinciannya di Noma!'
        : 'Malam ini! Belum ada pengeluaran dicatat hari ini. Yuk cek saldo atau catat transaksimu!';

    try {
      await _notificationsPlugin.show(
        dailyReminderId,
        'Pengingat Catat Harian',
        message,
        platformDetails,
        payload: _dailyReminderPayload,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  static Future<void> showDailyReminderNow() async {
    try {
      await _notificationsPlugin.show(
        dailyReminderId,
        'Pengingat Catat Harian',
        'Luangkan 1 menit untuk cek dan catat transaksi hari ini di Noma.',
        const NotificationDetails(android: _androidDetails),
        payload: _dailyReminderPayload,
      );
    } catch (e) {
      debugPrint('Error showing reminder notification: $e');
    }
  }

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        dailyReminderId,
        'Pengingat Catat Harian',
        'Sebelum hari selesai, catat transaksi kecil yang mungkin terlupa.',
        _nextInstanceOfTime(hour: hour, minute: minute),
        const NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: _dailyReminderPayload,
      );
    } catch (e) {
      debugPrint('Error scheduling daily reminder: $e');
      rethrow;
    }
  }

  static Future<void> cancelDailyReminder() async {
    try {
      await _notificationsPlugin.cancel(dailyReminderId);
    } catch (e) {
      debugPrint('Error cancelling daily reminder: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOfTime({
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'daily_reminder_channel',
        'Pengingat Catat Harian',
        channelDescription:
            'Notifikasi harian untuk mengingatkan pengguna mencatat transaksi',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
}
