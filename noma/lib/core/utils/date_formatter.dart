import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String formatFullDate(DateTime date) {
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
  }

  static String formatShortDate(DateTime date) {
    return DateFormat('d MMM yyyy', 'id_ID').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm', 'id_ID').format(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final difference = today.difference(target).inDays;

    if (difference == 0) {
      return 'Hari ini, ${formatTime(date)}';
    } else if (difference == 1) {
      return 'Kemarin, ${formatTime(date)}';
    } else {
      return formatShortDate(date);
    }
  }
}
