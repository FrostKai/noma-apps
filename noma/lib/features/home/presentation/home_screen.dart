import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../core/constants/app_color_scheme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_images.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/product_tour_keys.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/animated_number_counter.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_glass_card.dart';
import '../../main_shell/presentation/main_shell_screen.dart';
import '../../transaction/data/transaction_repository.dart';
import '../../transaction/presentation/add_transaction_screen.dart';
import '../../transaction/presentation/providers/transaction_provider.dart';
import '../../transaction/presentation/widgets/transaction_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorScheme.of(context);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);
    final summaryArgs = (
      startMs: monthStart.millisecondsSinceEpoch,
      endMs: nextMonthStart.millisecondsSinceEpoch,
    );

    final balanceAsync = ref.watch(totalBalanceStreamProvider);
    final monthlySummaryAsync = ref.watch(
      transactionSummaryStreamProvider(summaryArgs),
    );
    final latestTransactionsAsync = ref.watch(
      latestTransactionsStreamProvider(5),
    );

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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(totalBalanceStreamProvider);
            ref.invalidate(transactionSummaryStreamProvider(summaryArgs));
            ref.invalidate(latestTransactionsStreamProvider(5));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              _buildHeader(context, ref),
              const SizedBox(height: 20),
              Showcase(
                key: ProductTourKeys.dashboardChart,
                title: 'Periode Aktif',
                description:
                    'Dashboard menampilkan snapshot singkat untuk periode berjalan.',
                targetBorderRadius: BorderRadius.circular(18),
                targetPadding: const EdgeInsets.all(4),
                tooltipBackgroundColor: tourTooltipBg,
                titleTextStyle: tourTitleStyle,
                descTextStyle: tourDescStyle,
                child: _buildPeriodCard(context, now),
              ),
              const SizedBox(height: 16),
              Showcase(
                key: ProductTourKeys.balanceCard,
                title: 'Saldo Utama',
                description: 'Saldo bersih dari seluruh transaksi tersimpan.',
                targetBorderRadius: BorderRadius.circular(24),
                targetPadding: const EdgeInsets.all(4),
                tooltipBackgroundColor: tourTooltipBg,
                titleTextStyle: tourTitleStyle,
                descTextStyle: tourDescStyle,
                child: _buildBalanceCard(context, balanceAsync),
              ),
              const SizedBox(height: 16),
              Showcase(
                key: ProductTourKeys.aiSmartInput,
                title: 'Ringkasan Bulan Ini',
                description:
                    'Pemasukan dan pengeluaran bulan berjalan secara ringkas.',
                targetBorderRadius: BorderRadius.circular(18),
                targetPadding: const EdgeInsets.all(4),
                tooltipBackgroundColor: tourTooltipBg,
                titleTextStyle: tourTitleStyle,
                descTextStyle: tourDescStyle,
                child: _buildMonthlySummaryCard(context, monthlySummaryAsync),
              ),
              const SizedBox(height: 22),
              Showcase(
                key: ProductTourKeys.recentTx,
                title: 'Transaksi Terbaru',
                description:
                    'Dashboard hanya menampilkan preview. Buka halaman Transaksi untuk histori lengkap.',
                targetBorderRadius: BorderRadius.circular(18),
                targetPadding: const EdgeInsets.all(4),
                tooltipBackgroundColor: tourTooltipBg,
                titleTextStyle: tourTitleStyle,
                descTextStyle: tourDescStyle,
                child: _buildLatestTransactionsCard(
                  context,
                  latestTransactionsAsync,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset(
          AppImages.logoWordmark,
          height: 38,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Text('Noma', style: AppTypography.headingLarge),
        ),
        GlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: 12,
          onTap: () => ref.read(activeTabProvider.notifier).state = 3,
          child: Icon(
            Icons.settings_outlined,
            color: AppColorScheme.of(context).textSecondary,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodCard(BuildContext context, DateTime now) {
    final colors = AppColorScheme.of(context);
    final label = DateFormat('MMMM yyyy', 'id_ID').format(now);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Periode saat ini',
                  style: AppTypography.caption.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  label,
                  style: AppTypography.labelLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.report),
            icon: const Icon(Icons.bar_chart_rounded, size: 18),
            label: const Text('Laporan'),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    AsyncValue<double> balanceAsync,
  ) {
    final balance = balanceAsync.valueOrNull ?? 0.0;
    final colors = AppColorScheme.of(context);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      shadows: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 36,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo Total',
            style: AppTypography.labelMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedNumberCounter(
            targetAmount: balance,
            style: AppTypography.amountDisplay.copyWith(
              color: balance >= 0 ? colors.textPrimary : AppColors.expense,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Seluruh transaksi',
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryCard(
    BuildContext context,
    AsyncValue<TransactionSummary> summaryAsync,
  ) {
    final colors = AppColorScheme.of(context);

    return summaryAsync.when(
      data: (summary) => GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ringkasan Bulan Ini',
                    style: AppTypography.labelLarge.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${summary.count} transaksi',
                  style: AppTypography.caption.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    context,
                    label: 'Pemasukan',
                    value: summary.income,
                    color: AppColors.income,
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryMetric(
                    context,
                    label: 'Pengeluaran',
                    value: summary.expense,
                    color: AppColors.expense,
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => const GlassCard(
        padding: EdgeInsets.all(18),
        child: LinearProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) => GlassCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Error memuat ringkasan: $err',
          style: AppTypography.caption.copyWith(color: AppColors.expense),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(
    BuildContext context, {
    required String label,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    final colors = AppColorScheme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatRupiahCompact(value),
            style: AppTypography.labelLarge.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestTransactionsCard(
    BuildContext context,
    AsyncValue<List<Transaction>> latestAsync,
  ) {
    final colors = AppColorScheme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Transaksi Terbaru',
                  style: AppTypography.labelLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push(AppRoutes.transactions),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Lihat semua'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          latestAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return _buildEmptyLatest(context);
              }

              return Column(
                children: transactions.map((tx) {
                  return TransactionCard(
                    transaction: tx,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              AddTransactionScreen(initialTransaction: tx),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (err, _) => Text(
              'Error memuat transaksi: $err',
              style: AppTypography.caption.copyWith(color: AppColors.expense),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLatest(BuildContext context) {
    final colors = AppColorScheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: colors.textMuted, size: 40),
          const SizedBox(height: 10),
          Text(
            'Belum ada transaksi.',
            style: AppTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          GlassButton(
            label: 'Tambah Transaksi',
            icon: Icons.add_rounded,
            variant: GlassButtonVariant.primary,
            height: 44,
            onPressed: () => context.push(AppRoutes.addTransaction),
          ),
        ],
      ),
    );
  }
}
