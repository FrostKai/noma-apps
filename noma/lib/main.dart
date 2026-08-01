import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Indonesian locale for Intl formatting
  await initializeDateFormatting('id_ID', null);

  // Initialize Local Notifications Service (not supported on web)
  if (!kIsWeb) {
    await NotificationService.initialize();
  }

  // Load environment variables (.env file)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }

  runApp(
    const ProviderScope(
      child: NomaApp(),
    ),
  );
}
