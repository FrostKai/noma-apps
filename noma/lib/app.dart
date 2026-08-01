import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/smooth_scroll_behavior.dart';

class NomaApp extends StatelessWidget {
  const NomaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SmoothScrollBehavior(),
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
