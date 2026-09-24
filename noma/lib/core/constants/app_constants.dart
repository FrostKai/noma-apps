/// Application global constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Noma';
  static const String appTagline = 'Catat Uang Pintar dengan AI';

  // Database
  static const String dbName = 'noma_app.db';

  // Shared Preferences / App Settings Keys
  static const String keyDailyNotificationEnabled =
      'daily_notification_enabled';
  static const String keyDailyNotificationTime = 'daily_notification_time';

  // Default values
  static const String defaultNotificationTime = '20:00';
}
