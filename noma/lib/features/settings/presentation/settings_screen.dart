import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_images.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_typography.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pengaturan', style: AppTypography.headingMedium),
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Category Management Menu
          GlassCard(
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
                        style: AppTypography.labelLarge,
                      ),
                      Text(
                        'Atur kategori pemasukan & pengeluaran',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daily Night Notification Section
          Text('Notifikasi & Pengingat', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          GlassCard(
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
                            style: AppTypography.labelLarge,
                          ),
                          Text(
                            _notificationEnabled
                                ? 'Noma akan mengingatkan kamu setiap hari jam ${_formatTime(_notificationTime)}'
                                : 'Aktifkan agar tidak lupa mencatat transaksi',
                            style: AppTypography.caption,
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
                const Divider(color: AppColors.glassBorder),
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
                      color: AppColors.background.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder),
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
                                style: AppTypography.labelLarge,
                              ),
                              Text(
                                'Ketuk untuk mengubah waktu notifikasi harian',
                                style: AppTypography.caption,
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
                  label: 'Uji Coba Notifikasi Sekarang',
                  icon: Icons.notifications_none_rounded,
                  variant: GlassButtonVariant.outline,
                  height: 42,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    if (kIsWeb) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Notifikasi tidak didukung di web. Coba di perangkat Android.',
                          ),
                          backgroundColor: AppColors.expense,
                        ),
                      );
                      return;
                    }
                    await NotificationService.showDailyReminderNow();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Notifikasi uji coba dikirim! Cek tray notifikasi HP.',
                        ),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // AI Integration Info & API Key Setup
          Text('Kecerdasan Buatan (AI)', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          GlassCard(
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
                        'Groq Cloud AI (Llama 3.3 70B)',
                        style: AppTypography.labelLarge,
                      ),
                      Text(
                        'Ketuk untuk atur API Key gratis',
                        style: AppTypography.caption,
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
                    width: 54,
                    height: 54,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Image.asset(
                    AppImages.logoWordmark,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aplikasi Pencatatan Keuangan Berbasis AI',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Versi 1.0.0 (Build 1)',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.expense : AppColors.primary,
      ),
    );
  }
}
