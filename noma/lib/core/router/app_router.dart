import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/transaction/presentation/add_transaction_screen.dart';
import '../../features/transaction/presentation/transaction_history_screen.dart';
import '../../features/receipt_scanner/presentation/scanner_screen.dart';
import '../../features/chatbot/presentation/chatbot_screen.dart';
import '../../features/report/presentation/report_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/category/presentation/category_screen.dart';

import '../../features/main_shell/presentation/main_shell_screen.dart';

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const MainShellScreen(),
    ),
    GoRoute(
      path: AppRoutes.transactions,
      builder: (context, state) => const TransactionHistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.addTransaction,
      builder: (context, state) => const AddTransactionScreen(),
    ),
    GoRoute(
      path: AppRoutes.scanner,
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: AppRoutes.chatbot,
      builder: (context, state) => const ChatbotScreen(),
    ),
    GoRoute(
      path: AppRoutes.report,
      builder: (context, state) => const ReportScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.categories,
      builder: (context, state) => const CategoryScreen(),
    ),
  ],
);
