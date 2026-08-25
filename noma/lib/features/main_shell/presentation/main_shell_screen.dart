import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/constants/app_color_scheme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/product_tour_keys.dart';
import '../../../core/services/product_tour_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ai_key_setup_modal.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../../../shared/widgets/glass_reflection_background.dart';
import '../../chatbot/presentation/chatbot_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../report/presentation/report_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../transaction/presentation/widgets/ai_smart_input_card.dart';

final activeTabProvider = StateProvider<int>((ref) => 0);

class MainShellScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainShellScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fabController;
  int _currentIndex = 0;
  bool _isFabExpanded = false;
  BuildContext? _showcaseContext;

  AnimationController get fabController => _fabController;

  final List<Widget> _pages = const [
    HomeScreen(),
    ChatbotScreen(isTabPage: true),
    ReportScreen(),
    SettingsScreen(),
  ];

  String _getTourDescription(int navIndex) {
    switch (navIndex) {
      case 0:
        return 'Kembali ke beranda! Sekarang mari kenali fitur-fiturnya.';
      case 1:
        return 'Chat dengan Nomi, asisten AI keuangan pribadi Anda.';
      case 3:
        return 'Lihat laporan dan statistik keuangan lengkap Anda.';
      case 4:
        return 'Mari setup aplikasi Anda terlebih dahulu.';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hasSeen = await ProductTourService.hasSeenTour();
      if (!hasSeen && mounted && _showcaseContext != null) {
        ShowcaseView.get().startShowCase(ProductTourKeys.orderedKeys);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_isFabExpanded) {
      _toggleFab();
    }
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  void _showAiTextInputModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: const AiSmartInputCard(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    ref.listen(activeTabProvider, (prev, next) {
      if (next != _currentIndex) {
        _onTabTapped(next);
      }
    });

    ref.listen(productTourTriggerProvider, (prev, next) {
      if (next > 0 && mounted) {
        ProductTourKeys.refreshKeys();
        if (_isFabExpanded) _toggleFab();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _onTabTapped(0);
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted && _showcaseContext != null) {
            ShowcaseView.get().startShowCase(ProductTourKeys.orderedKeys);
          }
        });
      }
    });

    // ignore: deprecated_member_use
    return ShowCaseWidget(
      enableAutoScroll: true,
      scrollDuration: const Duration(milliseconds: 400),
      onFinish: () {
        if (_isFabExpanded) _toggleFab();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _onTabTapped(0);
        ProductTourService.markTourAsCompleted();
      },
      onComplete: (index, key) {
        // Saat Step 3 (settingsAiKey) selesai (user klik Berikutnya),
        // Buka modal OverlayEntry & tunggu 300ms agar modal ter-render, lalu lanjutkan tour ke modalGroqBtn
        if (key == ProductTourKeys.settingsAiKey) {
          AiKeySetupModal.show(context);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _showcaseContext != null) {
              ShowcaseView.get().startShowCase([
                ProductTourKeys.modalGroqBtn,
                ProductTourKeys.modalGroqInput,
                ProductTourKeys.modalGeminiBtn,
                ProductTourKeys.modalGeminiInput,
                ProductTourKeys.settingsCategory,
                ProductTourKeys.settingsNotification,
                ProductTourKeys.navBeranda,
                ProductTourKeys.dashboardChart,
                ProductTourKeys.aiSmartInput,
                ProductTourKeys.recentTx,
                ProductTourKeys.navNomiAI,
                ProductTourKeys.navTambah,
                ProductTourKeys.navLaporan,
              ]);
            }
          });
        }
      },
      onStart: (index, key) {
        // Step 2: Pindah ke tab Pengaturan saat step navPengaturan dimulai
        if (key == ProductTourKeys.navPengaturan) {
          if (_isFabExpanded) _toggleFab();
          _onTabTapped(3); // index 3 = Pengaturan
        }
        // Step 3: Highlight Card Setup AI Key di Pengaturan — modal BELUM terbuka
        else if (key == ProductTourKeys.settingsAiKey) {
          if (_isFabExpanded) _toggleFab();
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          _onTabTapped(3);
        }
        // Step 4: Modal terbuka (dimulai dari onComplete step 3)
        else if (key == ProductTourKeys.modalGroqBtn) {
          if (_isFabExpanded) _toggleFab();
          _onTabTapped(3);
          AiKeySetupModal.show(context);
        }
        // Step 8: Tutup modal, lanjut ke Kategori di Pengaturan
        else if (key == ProductTourKeys.settingsCategory) {
          if (_isFabExpanded) _toggleFab();
          AiKeySetupModal.dismiss();
        }
        // Step 10: Pindah ke Beranda
        else if (key == ProductTourKeys.navBeranda) {
          if (_isFabExpanded) _toggleFab();
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          _onTabTapped(0);
        }
        // Step 11: Pindah ke Nomi AI
        else if (key == ProductTourKeys.navNomiAI) {
          if (_isFabExpanded) _toggleFab();
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          _onTabTapped(1);
        }
        // Step 12: Mekarkan FAB
        else if (key == ProductTourKeys.navTambah) {
          if (!_isFabExpanded) _toggleFab();
        }
        // Step 13: Pindah ke Laporan
        else if (key == ProductTourKeys.navLaporan) {
          if (_isFabExpanded) _toggleFab();
          _onTabTapped(2);
        }
      },
      blurValue: 1.0,
      builder: (ctx) {
        _showcaseContext = ctx;
        final colors = AppColorScheme.of(context);
        return Scaffold(
          backgroundColor: colors.background,
          resizeToAvoidBottomInset: false,
          body: GlassReflectionBackground(
            child: Stack(
              children: [
                // PageView with smooth swipe gestures between tabs
                PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    if (_currentIndex != index) {
                      setState(() {
                        _currentIndex = index;
                      });
                      ref.read(activeTabProvider.notifier).state = index;
                    }
                  },
                  children: _pages,
                ),

                // Semi-transparent Scrim Overlay when FAB is expanded
                if (_isFabExpanded)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleFab,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedBuilder(
                        animation: fabController,
                        builder: (context, child) {
                          return Container(
                            color: Colors.black.withValues(
                              alpha: 0.55 * fabController.value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Floating Navigation Bar
                if (!isKeyboardOpen)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _buildFloatingGlassNavBar(context),
                  ),

                // Fanned Action Buttons Container (Rendered ON TOP of Navigation Bar)
                if (!isKeyboardOpen && _isFabExpanded)
                  Positioned.fill(child: _buildFannedActionButtons()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFannedActionButtons() {
    const springCurve = Cubic(0.34, 1.56, 0.64, 1.0);

    final anim1 = CurvedAnimation(
      parent: fabController,
      curve: const Interval(0.0, 0.75, curve: springCurve),
    );
    final anim2 = CurvedAnimation(
      parent: fabController,
      curve: const Interval(0.12, 0.88, curve: springCurve),
    );
    final anim3 = CurvedAnimation(
      parent: fabController,
      curve: const Interval(0.25, 1.0, curve: springCurve),
    );

    final actions = [
      {
        'label': 'Scan Struk',
        'icon': Icons.document_scanner_rounded,
        'color': AppColors.primary,
        'offset': const Offset(-68, -60),
        'anim': anim1,
        'onTap': () {
          _toggleFab();
          context.push(AppRoutes.scanner);
        },
      },
      {
        'label': 'AI Teks',
        'icon': Icons.auto_awesome_rounded,
        'color': AppColors.info,
        'offset': const Offset(0, -88),
        'anim': anim2,
        'onTap': () {
          _toggleFab();
          _showAiTextInputModal(context);
        },
      },
      {
        'label': 'Manual',
        'icon': Icons.edit_note_rounded,
        'color': AppColors.income,
        'offset': const Offset(68, -60),
        'anim': anim3,
        'onTap': () {
          _toggleFab();
          context.push(AppRoutes.addTransaction);
        },
      },
    ];

    return AnimatedBuilder(
      animation: fabController,
      builder: (context, child) {
        if (fabController.isDismissed && !_isFabExpanded) {
          return const SizedBox.shrink();
        }

        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: actions.map((item) {
            final anim = item['anim'] as Animation<double>;
            final offset = item['offset'] as Offset;
            final icon = item['icon'] as IconData;
            final label = item['label'] as String;
            final onTap = item['onTap'] as VoidCallback;
            final color = item['color'] as Color;

            final currentOffset = Offset(
              offset.dx * anim.value,
              -64 + (offset.dy * anim.value),
            );
            final scale = 0.4 + (0.6 * anim.value.clamp(0.0, 1.5));
            final opacity = anim.value.clamp(0.0, 1.0);

            return Transform.translate(
              offset: currentOffset,
              child: Opacity(
                opacity: opacity,
                child: BouncyTap(
                  onTap: onTap,
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: 82,
                      height: 78,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColorScheme.of(
                                context,
                              ).backgroundSecondary.withValues(alpha: 0.95),
                              border: Border.all(
                                color: color.withValues(alpha: 0.7),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(icon, color: color, size: 22),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              label,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFloatingGlassNavBar(BuildContext context) {
    final colors = AppColorScheme.of(context);
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
            color: colors.navBarBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.navBarBorder, width: 1.0),
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

              GlobalKey? tourKey;
              switch (index) {
                case 0:
                  tourKey = ProductTourKeys.navBeranda;
                  break;
                case 1:
                  tourKey = ProductTourKeys.navNomiAI;
                  break;
                case 3:
                  tourKey = ProductTourKeys.navLaporan;
                  break;
                case 4:
                  tourKey = ProductTourKeys.navPengaturan;
                  break;
              }

              Widget navWidget = BouncyTap(
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
                            : colors.textMuted,
                      ),
                    ),
                  ),
                ),
              );

              if (tourKey != null) {
                navWidget = Showcase(
                  key: tourKey,
                  title: item['label'] as String,
                  description: _getTourDescription(index),
                  targetShapeBorder: const CircleBorder(),
                  targetPadding: const EdgeInsets.all(4),
                  tooltipBackgroundColor: const Color(0xE61A1A2E),
                  titleTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  descTextStyle: const TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  child: navWidget,
                );
              }

              return navWidget;
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildFabItem(BuildContext context) {
    return Showcase(
      key: ProductTourKeys.navTambah,
      title: 'Tambah Transaksi',
      description:
          'Ketuk untuk menambah transaksi:\nScan Struk, AI Teks, atau Manual.',
      targetShapeBorder: const CircleBorder(),
      targetPadding: const EdgeInsets.all(4),
      tooltipBackgroundColor: const Color(0xE61A1A2E),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      descTextStyle: const TextStyle(
        color: Color(0xD9FFFFFF),
        fontSize: 13,
        height: 1.4,
      ),
      child: BouncyTap(
        onTap: _toggleFab,
        scaleFactor: 0.88,
        child: AnimatedBuilder(
          animation: fabController,
          builder: (context, child) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isFabExpanded
                    ? LinearGradient(
                        colors: [
                          AppColors.expense,
                          AppColors.expense.withValues(alpha: 0.8),
                        ],
                      )
                    : AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color:
                        (_isFabExpanded ? AppColors.expense : AppColors.primary)
                            .withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: fabController.value * 0.75 * math.pi,
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
