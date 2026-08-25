import 'dart:async';

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
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../main_shell/presentation/main_shell_screen.dart';
import '../../transaction/presentation/add_transaction_screen.dart';
import '../../transaction/presentation/providers/transaction_provider.dart';
import '../../transaction/presentation/widgets/transaction_card.dart';

import '../../../shared/widgets/animated_number_counter.dart';
import '../../../shared/widgets/liquid_glass_card.dart';
import '../../transaction/data/transaction_repository.dart';
import 'widgets/dashboard_chart_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'expense', 'income'
  late DateTime _selectedMonth;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(totalBalanceStreamProvider);
    final incomeAsync = ref.watch(totalIncomeStreamProvider);
    final expenseAsync = ref.watch(totalExpenseStreamProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);
    final historyMonthStart = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final historyNextMonthStart = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );
    final historyArgs = (
      type: _filterType,
      searchQuery: _searchQuery,
      startMs: historyMonthStart.millisecondsSinceEpoch,
      endMs: historyNextMonthStart.millisecondsSinceEpoch,
      pageSize: defaultTransactionPageSize,
    );
    final monthlySummaryAsync = ref.watch(
      transactionSummaryStreamProvider((
        startMs: monthStart.millisecondsSinceEpoch,
        endMs: nextMonthStart.millisecondsSinceEpoch,
      )),
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

    final colors = AppColorScheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(
                  transactionHistoryControllerProvider(historyArgs).notifier,
                )
                .loadInitial();
            ref.invalidate(
              transactionSummaryStreamProvider((
                startMs: monthStart.millisecondsSinceEpoch,
                endMs: nextMonthStart.millisecondsSinceEpoch,
              )),
            );
            ref.invalidate(totalBalanceStreamProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList.list(
                  children: [
                    // Header with Time-Based Greeting
                    _buildHeader(context),
                    const SizedBox(height: 20),

                    // Glass Balance Card (Real-time Stream)
                    Showcase(
                      key: ProductTourKeys.balanceCard,
                      title: 'Saldo Utama',
                      description:
                          'Selamat datang di Noma! Ini ringkasan saldo, pemasukan & pengeluaran Anda.',
                      targetBorderRadius: BorderRadius.circular(24),
                      targetPadding: const EdgeInsets.all(4),
                      tooltipBackgroundColor: tourTooltipBg,
                      titleTextStyle: tourTitleStyle,
                      descTextStyle: tourDescStyle,
                      child: _buildBalanceCard(
                        balanceAsync,
                        incomeAsync,
                        expenseAsync,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Donut Chart + 7-Day Mini Bar Chart Card
                    Showcase(
                      key: ProductTourKeys.dashboardChart,
                      title: 'Grafik Keuangan',
                      description:
                          'Pantau distribusi pengeluaran dan perbandingan 7 hari terakhir.',
                      targetBorderRadius: BorderRadius.circular(24),
                      targetPadding: const EdgeInsets.all(4),
                      tooltipBackgroundColor: tourTooltipBg,
                      titleTextStyle: tourTitleStyle,
                      descTextStyle: tourDescStyle,
                      child: const DashboardChartCard(),
                    ),
                    const SizedBox(height: 20),

                    // Monthly summary card
                    Showcase(
                      key: ProductTourKeys.aiSmartInput,
                      title: 'Ringkasan Bulan Ini',
                      description:
                          'Lihat performa pemasukan dan pengeluaran bulan berjalan.',
                      targetBorderRadius: BorderRadius.circular(20),
                      targetPadding: const EdgeInsets.all(4),
                      tooltipBackgroundColor: tourTooltipBg,
                      titleTextStyle: tourTitleStyle,
                      descTextStyle: tourDescStyle,
                      child: _buildMonthlySummaryCard(
                        context,
                        monthlySummaryAsync,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Recent Transactions Header & Search/Filter
                    Text(
                      'Riwayat Transaksi',
                      style: AppTypography.headingMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildMonthSelector(context),
                    const SizedBox(height: 12),

                    // Search & Filter Bar
                    Showcase(
                      key: ProductTourKeys.recentTx,
                      title: 'Riwayat Transaksi',
                      description:
                          'Semua transaksi tercatat di sini.\nGunakan pencarian dan filter untuk menemukan transaksi.',
                      targetBorderRadius: BorderRadius.circular(16),
                      targetPadding: const EdgeInsets.all(4),
                      tooltipBackgroundColor: tourTooltipBg,
                      titleTextStyle: tourTitleStyle,
                      descTextStyle: tourDescStyle,
                      child: _buildSearchAndFilterBar(context),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              _TransactionHistorySliver(
                historyArgs: historyArgs,
                searchQuery: _searchQuery,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          onTap: () {
            ref.read(activeTabProvider.notifier).state = 3;
          },
          child: Icon(
            Icons.settings_outlined,
            color: AppColorScheme.of(context).textSecondary,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(
    AsyncValue<double> balanceAsync,
    AsyncValue<double> incomeAsync,
    AsyncValue<double> expenseAsync,
  ) {
    final balance = balanceAsync.valueOrNull ?? 0.0;
    final income = incomeAsync.valueOrNull ?? 0.0;
    final expense = expenseAsync.valueOrNull ?? 0.0;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Saldo Bersih',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Nomi AI',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedNumberCounter(
            targetAmount: balance,
            style: AppTypography.amountDisplay.copyWith(
              color: balance >= 0 ? colors.textPrimary : AppColors.expense,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: colors.glassBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        color: AppColors.income,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pemasukan', style: AppTypography.caption),
                        AnimatedNumberCounter(
                          targetAmount: income,
                          isCompact: true,
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: colors.glassBorder),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: AppColors.expense,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pengeluaran', style: AppTypography.caption),
                          AnimatedNumberCounter(
                            targetAmount: expense,
                            isCompact: true,
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
      data: (summary) {
        return GlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
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
                          'Ringkasan Bulan Ini',
                          style: AppTypography.labelLarge.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          '${summary.count} transaksi tercatat',
                          style: AppTypography.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatRupiahCompact(summary.balance),
                    style: AppTypography.labelLarge.copyWith(
                      color: summary.balance >= 0
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMonthlyMetric(
                      context,
                      'Masuk',
                      CurrencyFormatter.formatRupiahCompact(summary.income),
                      AppColors.income,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMonthlyMetric(
                      context,
                      'Keluar',
                      CurrencyFormatter.formatRupiahCompact(summary.expense),
                      AppColors.expense,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: colors.glassBorder),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.local_offer_rounded,
                    color: colors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.topExpenseCategory == null
                          ? 'Belum ada kategori pengeluaran bulan ini'
                          : 'Kategori terbesar: ${summary.topExpenseCategory}',
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  if (summary.topExpenseCategory != null)
                    Text(
                      CurrencyFormatter.formatRupiahCompact(
                        summary.topExpenseCategoryAmount,
                      ),
                      style: AppTypography.caption.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
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

  Widget _buildMonthlyMetric(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
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
          Text(
            label,
            style: AppTypography.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.labelLarge.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final filters = [
      {'key': 'all', 'label': 'Semua'},
      {'key': 'expense', 'label': 'Pengeluaran'},
      {'key': 'income', 'label': 'Pemasukan'},
    ];

    return Column(
      children: [
        // Search Input Field
        TextField(
          onChanged: (val) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            });
          },
          style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Cari transaksi (kategori, catatan, nominal)...',
            hintStyle: AppTypography.caption.copyWith(color: colors.textMuted),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            filled: true,
            fillColor: colors.glassSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Type Filter Chips
        Row(
          children: filters.map((f) {
            final isSelected = _filterType == f['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f['label']!),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: colors.glassSurface,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : colors.glassBorder,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : colors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  setState(() {
                    _filterType = f['key']!;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final canGoNext = _selectedMonth.isBefore(currentMonth);
    final label = DateFormat(
      'MMMM yyyy',
      'id_ID',
    ).format(_selectedMonth).toUpperCase();

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 16,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: () => _changeMonth(-1),
            icon: Icon(
              Icons.chevron_left_rounded,
              color: colors.textPrimary,
              size: 26,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: canGoNext ? () => _changeMonth(1) : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoNext ? colors.textPrimary : colors.textMuted,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int delta) {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    if (next.isAfter(currentMonth)) return;
    setState(() {
      _selectedMonth = next;
    });
  }
}

class _TransactionHistorySliver extends ConsumerWidget {
  final TransactionHistoryArgs historyArgs;
  final String searchQuery;

  const _TransactionHistorySliver({
    required this.historyArgs,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(
      transactionHistoryControllerProvider(historyArgs),
    );

    if (historyState.isInitialLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (historyState.error != null && historyState.transactions.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: GlassCard(
            child: Column(
              children: [
                Text(
                  'Error memuat transaksi: ${historyState.error}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.expense,
                  ),
                ),
                const SizedBox(height: 12),
                GlassButton(
                  label: 'Coba Lagi',
                  icon: Icons.refresh_rounded,
                  variant: GlassButtonVariant.secondary,
                  height: 42,
                  onPressed: () => ref
                      .read(
                        transactionHistoryControllerProvider(
                          historyArgs,
                        ).notifier,
                      )
                      .loadInitial(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (historyState.transactions.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: GlassCard(
            padding: const EdgeInsets.all(22),
            borderRadius: 16,
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'Transaksi tidak ditemukan'
                        : 'Belum ada transaksi di bulan ini',
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColorScheme.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'Coba gunakan kata kunci pencarian yang lain.'
                        : 'Mulai dengan tambah manual atau scan struk pertama kamu.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption,
                  ),
                  if (searchQuery.isEmpty) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: 'Tambah',
                            icon: Icons.add_rounded,
                            variant: GlassButtonVariant.income,
                            height: 44,
                            onPressed: () =>
                                context.push(AppRoutes.addTransaction),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GlassButton(
                            label: 'Scan',
                            icon: Icons.document_scanner_rounded,
                            variant: GlassButtonVariant.primary,
                            height: 44,
                            onPressed: () => context.push(AppRoutes.scanner),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final rows = _buildHistoryRows(historyState.transactions);
    final itemCount = rows.length + 1;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == rows.length) {
            return _buildHistoryFooter(context, ref, historyArgs, historyState);
          }

          final row = rows[index];
          if (row.header != null) {
            return _buildDateHeader(context, row.header!);
          }

          final tx = row.transaction!;
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
            onDelete: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus Transaksi?'),
                  content: Text(
                    'Yakin ingin menghapus transaksi ${tx.category} senilai ${CurrencyFormatter.formatRupiah(tx.amount)}?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Hapus',
                        style: TextStyle(color: AppColors.expense),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final success = await ref
                    .read(transactionControllerProvider.notifier)
                    .deleteTransaction(tx.id);
                if (success) {
                  ref
                      .read(
                        transactionHistoryControllerProvider(
                          historyArgs,
                        ).notifier,
                      )
                      .removeTransaction(tx.id);
                }
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    final colors = AppColorScheme.of(context);
    final label = DateFormat('d MMMM', 'id_ID').format(date).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: colors.glassBorder)),
        ],
      ),
    );
  }

  Widget _buildHistoryFooter(
    BuildContext context,
    WidgetRef ref,
    TransactionHistoryArgs historyArgs,
    TransactionHistoryState historyState,
  ) {
    if (historyState.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (historyState.error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: GlassButton(
          label: 'Coba Lagi',
          icon: Icons.refresh_rounded,
          variant: GlassButtonVariant.secondary,
          height: 44,
          onPressed: () => ref
              .read(transactionHistoryControllerProvider(historyArgs).notifier)
              .loadMore(),
        ),
      );
    }

    if (!historyState.hasMore) {
      return const SizedBox(height: 8);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: GlassButton(
        label: 'Muat Lagi',
        icon: Icons.expand_more_rounded,
        variant: GlassButtonVariant.secondary,
        height: 44,
        onPressed: () => ref
            .read(transactionHistoryControllerProvider(historyArgs).notifier)
            .loadMore(),
      ),
    );
  }

  List<_HistoryRow> _buildHistoryRows(List<Transaction> transactions) {
    final rows = <_HistoryRow>[];
    DateTime? lastDay;

    for (final tx in transactions) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx.transactionDate);
      final day = DateTime(date.year, date.month, date.day);
      if (lastDay != day) {
        rows.add(_HistoryRow.header(day));
        lastDay = day;
      }
      rows.add(_HistoryRow.transaction(tx));
    }

    return rows;
  }
}

class _HistoryRow {
  final DateTime? header;
  final Transaction? transaction;

  const _HistoryRow.header(this.header) : transaction = null;
  const _HistoryRow.transaction(this.transaction) : header = null;
}
