import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_images.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ai_key_setup_modal.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../transaction/presentation/providers/transaction_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationEnabled = true;
  final String _notificationTime = '20:00';

  @override
  Widget build(BuildContext context) {
    final todayExpenseAsync = ref.watch(totalExpenseStreamProvider);
    final todayExpense = todayExpenseAsync.valueOrNull ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pengaturan', style: AppTypography.headingMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                  child: const Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manajemen Kategori', style: AppTypography.labelLarge),
                      Text('Atur kategori pemasukan & pengeluaran', style: AppTypography.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
                      child: const Icon(Icons.notifications_active_rounded, color: AppColors.warning, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notifikasi Rangkuman Malam', style: AppTypography.labelLarge),
                          Text('Kirim ringkasan pengeluaran jam $_notificationTime', style: AppTypography.caption),
                        ],
                      ),
                    ),
                    Switch(
                      value: _notificationEnabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          _notificationEnabled = val;
                        });
                      },
                    ),
                  ],
                ),
                const Divider(color: AppColors.glassBorder),
                const SizedBox(height: 8),
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
                          content: Text('Notifikasi tidak didukung di web. Coba di perangkat Android.'),
                          backgroundColor: AppColors.expense,
                        ),
                      );
                      return;
                    }
                    await NotificationService.showDailyNightlySummary(
                      totalExpenseToday: todayExpense,
                    );
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Notifikasi uji coba dikirim! Cek tray notifikasi HP.'),
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
                  child: const Icon(Icons.auto_awesome, color: AppColors.income, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Google Gemini 2.0 Flash', style: AppTypography.labelLarge),
                      Text('Ketuk untuk atur API Key gratis', style: AppTypography.caption),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.income),
                  ),
                  child: Text('Atur Key', style: AppTypography.caption.copyWith(color: AppColors.income)),
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
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
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
}
