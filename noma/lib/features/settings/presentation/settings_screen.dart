import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/constants/app_color_scheme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_images.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/product_tour_keys.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/product_tour_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/ai_key_setup_modal.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 20, minute: 0);
  bool _isSavingNotification = false;
  bool _isTestingNotification = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(AppConstants.keyDailyNotificationEnabled) ?? false;
    final timeValue =
        prefs.getString(AppConstants.keyDailyNotificationTime) ??
        AppConstants.defaultNotificationTime;

    if (!mounted) return;
    setState(() {
      _notificationEnabled = enabled;
      _notificationTime = _parseTimeOfDay(timeValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    const tourTooltipBg = Color(0xE61A1A2E);
    const tourTitleStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    const tourDescStyle = TextStyle(
      color: Color(0xD9FFFFFF),
      fontSize: 13,
      height: 1.4,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Pengaturan',
          style: AppTypography.headingMedium.copyWith(
            color: colors.textPrimary,
          ),
        ),
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: colors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Theme Switcher Section
          Text(
            'Tampilan & Tema',
            style: AppTypography.labelMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final themeMode = ref.watch(themeModeProvider);
              return GlassCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        themeMode == ThemeMode.light
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tema Aplikasi',
                            style: AppTypography.labelLarge.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            themeMode == ThemeMode.light
                                ? 'Mode Terang (Warm Platinum)'
                                : 'Mode Gelap (Midnight Obsidian)',
                            style: AppTypography.caption.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Segmented Pill Switch
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colors.background.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Dark Mode Option Button
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.dark),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: themeMode == ThemeMode.dark
                                    ? AppColors.primary.withValues(alpha: 0.25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: themeMode == ThemeMode.dark
                                    ? Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.5,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.dark_mode_rounded,
                                    size: 14,
                                    color: themeMode == ThemeMode.dark
                                        ? AppColors.primary
                                        : colors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Gelap',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: themeMode == ThemeMode.dark
                                          ? AppColors.primary
                                          : colors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Light Mode Option Button
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.light),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: themeMode == ThemeMode.light
                                    ? AppColors.primary.withValues(alpha: 0.25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: themeMode == ThemeMode.light
                                    ? Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.5,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.light_mode_rounded,
                                    size: 14,
                                    color: themeMode == ThemeMode.light
                                        ? AppColors.primary
                                        : colors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Terang',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: themeMode == ThemeMode.light
                                          ? AppColors.primary
                                          : colors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Category Management Menu
          Showcase(
            key: ProductTourKeys.settingsCategory,
            title: 'Manajemen Kategori',
            description:
                'Atur kategori pemasukan & pengeluaran sesuai kebutuhan Anda.',
            targetBorderRadius: BorderRadius.circular(20),
            targetPadding: const EdgeInsets.all(4),
            tooltipBackgroundColor: tourTooltipBg,
            titleTextStyle: tourTitleStyle,
            descTextStyle: tourDescStyle,
            child: GlassCard(
              onTap: () => context.push(AppRoutes.categories),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manajemen Kategori',
                          style: AppTypography.labelLarge.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Atur kategori pemasukan & pengeluaran',
                          style: AppTypography.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Daily Night Notification Section
          Text(
            'Notifikasi & Pengingat',
            style: AppTypography.labelMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Showcase(
            key: ProductTourKeys.settingsNotification,
            title: 'Pengingat Harian',
            description:
                'Aktifkan notifikasi harian agar tidak lupa mencatat transaksi.',
            targetBorderRadius: BorderRadius.circular(20),
            targetPadding: const EdgeInsets.all(4),
            tooltipBackgroundColor: tourTooltipBg,
            titleTextStyle: tourTitleStyle,
            descTextStyle: tourDescStyle,
            child: GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengingat Catat Harian',
                              style: AppTypography.labelLarge.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              _notificationEnabled
                                  ? 'Noma akan mengingatkan kamu setiap hari jam ${_formatTime(_notificationTime)}'
                                  : 'Aktifkan agar tidak lupa mencatat transaksi',
                              style: AppTypography.caption.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _notificationEnabled,
                        activeTrackColor: AppColors.primary,
                        onChanged: _isSavingNotification
                            ? null
                            : (val) => _setNotificationEnabled(val),
                      ),
                    ],
                  ),
                  Divider(color: colors.glassBorder),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isSavingNotification ? null : _pickNotificationTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.background.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jam Pengingat',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Ketuk untuk mengubah waktu notifikasi harian',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTime(_notificationTime),
                            style: AppTypography.headingSmall.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassButton(
                    label: _isTestingNotification
                        ? 'Mengirim...'
                        : 'Uji Coba Notifikasi Sekarang',
                    icon: Icons.notifications_none_rounded,
                    variant: GlassButtonVariant.outline,
                    height: 42,
                    isLoading: _isTestingNotification,
                    onPressed: _isTestingNotification
                        ? null
                        : () async {
                            if (kIsWeb) {
                              _showSnackBar(
                                'Notifikasi tidak didukung di web. Coba di perangkat Android.',
                                isError: true,
                              );
                              return;
                            }
                            setState(() {
                              _isTestingNotification = true;
                            });
                            try {
                              await NotificationService.showDailyReminderNow();
                              _showSnackBar(
                                'Notifikasi uji coba dikirim! Cek tray notifikasi HP.',
                              );
                            } catch (_) {
                              _showSnackBar(
                                'Gagal menguji notifikasi.',
                                isError: true,
                              );
                            } finally {
                              Future.delayed(
                                const Duration(milliseconds: 1500),
                                () {
                                  if (mounted) {
                                    setState(() {
                                      _isTestingNotification = false;
                                    });
                                  }
                                },
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // AI Integration Info & API Key Setup
          Text(
            'Kecerdasan Buatan (AI)',
            style: AppTypography.labelMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Showcase(
            key: ProductTourKeys.settingsAiKey,
            title: 'Setup API Key AI (100% Gratis)',
            description:
                'Di sini tempat memasukkan Kunci AI (100% Gratis).\n\n'
                'Tekan "Berikutnya" untuk membuka jendela pengaturan dan panduan pengambilannya!',
            tooltipPosition: TooltipPosition.top,
            targetBorderRadius: BorderRadius.circular(20),
            targetPadding: const EdgeInsets.all(4),
            tooltipBackgroundColor: tourTooltipBg,
            titleTextStyle: tourTitleStyle,
            descTextStyle: tourDescStyle,
            child: GlassCard(
              onTap: () => AiKeySetupModal.show(context),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.income.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.income,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Groq Cloud AI',
                          style: AppTypography.labelLarge.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Ketuk untuk atur API Key gratis',
                          style: AppTypography.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.income.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.income),
                    ),
                    child: Text(
                      'Atur Key',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.income,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Help & Product Tour Repeat
          Text(
            'Bantuan',
            style: AppTypography.labelMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            onTap: () async {
              await ProductTourService.resetTour();
              ref.read(productTourTriggerProvider.notifier).state++;
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ulangi Tur Aplikasi',
                        style: AppTypography.labelLarge.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Tampilkan panduan fitur aplikasi lagi',
                        style: AppTypography.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // App Branding Card (Logo Icon & Wordmark)
          Center(
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 20,
              child: Column(
                children: [
                  Image.asset(
                    AppImages.logoIcon,
                    width: 68,
                    height: 68,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Image.asset(
                    AppImages.logoWordmark,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aplikasi Pencatatan Keuangan Berbasis AI',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Versi 1.0.0 (Build 1)',
                    style: AppTypography.caption.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 115),
        ],
      ),
    );
  }

  Future<void> _setNotificationEnabled(bool enabled) async {
    if (kIsWeb) {
      _showSnackBar(
        'Notifikasi tidak didukung di web. Coba di perangkat Android.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSavingNotification = true;
    });

    try {
      if (enabled) {
        await NotificationService.scheduleDailyReminder(
          hour: _notificationTime.hour,
          minute: _notificationTime.minute,
        );
      } else {
        await NotificationService.cancelDailyReminder();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyDailyNotificationEnabled, enabled);
      await prefs.setString(
        AppConstants.keyDailyNotificationTime,
        _formatTime(_notificationTime),
      );

      if (!mounted) return;
      setState(() {
        _notificationEnabled = enabled;
      });
      _showSnackBar(
        enabled
            ? 'Pengingat harian aktif jam ${_formatTime(_notificationTime)}.'
            : 'Pengingat harian dinonaktifkan.',
      );
    } catch (e) {
      _showSnackBar(
        'Gagal mengatur notifikasi. Periksa izin notifikasi di pengaturan HP.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingNotification = false;
        });
      }
    }
  }

  Future<void> _pickNotificationTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        final isLight = AppColorScheme.isLight(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isLight
                ? const ColorScheme.light(
                    primary: AppColors.primary,
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  )
                : const ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: AppColors.surface,
                    onSurface: AppColors.textPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _notificationTime = picked;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.keyDailyNotificationTime,
      _formatTime(picked),
    );

    if (_notificationEnabled && !kIsWeb) {
      try {
        await NotificationService.scheduleDailyReminder(
          hour: picked.hour,
          minute: picked.minute,
        );
      } catch (_) {
        _showSnackBar(
          'Jam tersimpan, tapi jadwal notifikasi belum berhasil dibuat.',
          isError: true,
        );
        return;
      }
    }

    _showSnackBar('Jam pengingat diubah ke ${_formatTime(picked)}.');
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 20 : 20;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError ? AppColors.expense : AppColors.primary,
      ),
    );
  }
}
