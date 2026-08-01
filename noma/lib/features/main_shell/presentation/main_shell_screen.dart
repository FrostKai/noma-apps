import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../../../shared/widgets/glass_reflection_background.dart';
import '../../chatbot/presentation/chatbot_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../report/presentation/report_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int initialIndex;

  const MainShellScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;
  late PageController _pageController;

  final List<Widget> _pages = const [
    HomeScreen(),
    ChatbotScreen(isTabPage: true),
    ReportScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: GlassReflectionBackground(
        child: Stack(
          children: [
            // Smooth Animated Page Transition with Horizontal Swipe Support
            PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                if (_currentIndex != index) {
                  setState(() {
                    _currentIndex = index;
                  });
                }
              },
              children: _pages,
            ),

            // Floating Navigation Bar (Hidden when soft keyboard is active to prevent overflow)
            if (!isKeyboardOpen)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildFloatingGlassNavBar(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingGlassNavBar(BuildContext context) {
    final navItems = [
      {'icon': Icons.grid_view_rounded, 'label': 'Beranda'},
      {'icon': Icons.auto_awesome_rounded, 'label': 'Nomi AI'},
      {'icon': Icons.add_rounded, 'isFab': true, 'label': 'Tambah'},
      {'icon': Icons.pie_chart_rounded, 'label': 'Laporan'},
      {'icon': Icons.settings_rounded, 'label': 'Pengaturan'},
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 36,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isFab = item['isFab'] == true;

              if (isFab) {
                return _buildFabItem(context);
              }

              final pageIndex = index > 2 ? index - 1 : index;
              final isSelected = _currentIndex == pageIndex;

              return BouncyTap(
                onTap: () => _onTabTapped(pageIndex),
                scaleFactor: 0.9,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.45)
                          : Colors.transparent,
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 14,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: isSelected ? 1.18 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        item['icon'] as IconData,
                        size: 23,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildFabItem(BuildContext context) {
    return BouncyTap(
      onTap: () {
        context.push(AppRoutes.addTransaction);
      },
      scaleFactor: 0.88,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}
