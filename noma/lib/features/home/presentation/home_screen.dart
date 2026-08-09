import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
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
import '../../transaction/presentation/widgets/ai_smart_input_card.dart';
import '../../transaction/presentation/widgets/transaction_card.dart';

import '../../../shared/widgets/animated_number_counter.dart';
import '../../../shared/widgets/animated_slide_fade.dart';
import '../../../shared/widgets/liquid_glass_card.dart';
import 'widgets/dashboard_chart_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'expense', 'income'

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(totalBalanceStreamProvider);
    final incomeAsync = ref.watch(totalIncomeStreamProvider);
    final expenseAsync = ref.watch(totalExpenseStreamProvider);
    final recentTxAsync = ref.watch(allTransactionsStreamProvider);

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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recentTransactionsStreamProvider);
            ref.invalidate(allTransactionsStreamProvider);
            ref.invalidate(totalBalanceStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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

                // AI Natural Language Smart Input Card
                Showcase(
                  key: ProductTourKeys.aiSmartInput,
                  title: 'Input AI Cerdas',
                  description:
                      'Setelah API key aktif, ketik transaksi dengan bahasa alami!\nContoh: "Beli kopi 25rb".',
                  targetBorderRadius: BorderRadius.circular(20),
                  targetPadding: const EdgeInsets.all(4),
                  tooltipBackgroundColor: tourTooltipBg,
                  titleTextStyle: tourTitleStyle,
                  descTextStyle: tourDescStyle,
                  child: const AiSmartInputCard(),
                ),
                const SizedBox(height: 20),

                // Quick Action Glass Chips
                Showcase(
                  key: ProductTourKeys.quickActions,
                  title: 'Aksi Cepat',
                  description:
                      'Akses cepat ke fitur utama: Tambah, Scan Struk, Nomi AI, dan Laporan.',
                  targetBorderRadius: BorderRadius.circular(16),
                  targetPadding: const EdgeInsets.all(4),
                  tooltipBackgroundColor: tourTooltipBg,
                  titleTextStyle: tourTitleStyle,
                  descTextStyle: tourDescStyle,
                  child: _buildQuickActions(context),
                ),
                const SizedBox(height: 28),

                // Recent Transactions Header & Search/Filter
                Text('Riwayat Transaksi', style: AppTypography.headingMedium),
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
                  child: _buildSearchAndFilterBar(),
                ),
                const SizedBox(height: 16),

                // Recent Transactions List (Filtered Real-time Stream)
                _buildRecentTransactionsList(context, ref, recentTxAsync),
                const SizedBox(height: 100),
              ],
            ),
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
          child: const Icon(
            Icons.settings_outlined,
            color: AppColors.textSecondary,
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
                  color: AppColors.textSecondary,
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
              color: balance >= 0 ? AppColors.textPrimary : AppColors.expense,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.glassBorder),
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
              Container(width: 1, height: 32, color: AppColors.glassBorder),
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

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {
        'title': 'Tambah',
        'icon': Icons.add_circle_outline_rounded,
        'color': AppColors.income,
        'route': AppRoutes.addTransaction,
      },
      {
        'title': 'Scan',
        'icon': Icons.document_scanner_rounded,
        'color': AppColors.primary,
        'route': AppRoutes.scanner,
      },
      {
        'title': 'Nomi AI',
        'icon': Icons.chat_bubble_outline_rounded,
        'color': AppColors.info,
        'route': AppRoutes.chatbot,
      },
      {
        'title': 'Laporan',
        'icon': Icons.pie_chart_outline_rounded,
        'color': AppColors.warning,
        'route': AppRoutes.report,
      },
    ];

    return Row(
      children: actions.map((action) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              borderRadius: 16,
              onTap: () {
                context.push(action['route'] as String);
              },
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (action['color'] as Color).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      action['icon'] as IconData,
                      color: action['color'] as Color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action['title'] as String,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchAndFilterBar() {
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
            setState(() {
              _searchQuery = val.trim().toLowerCase();
            });
          },
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Cari transaksi (kategori, catatan, nominal)...',
            hintStyle: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            filled: true,
            fillColor: AppColors.glassSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.glassBorder),
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
                backgroundColor: AppColors.glassSurface,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.glassBorder,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
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

  Widget _buildRecentTransactionsList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Transaction>> recentTxAsync,
  ) {
    return recentTxAsync.when(
      data: (transactions) {
        // Filter transactions by query & type
        final filtered = transactions.where((tx) {
          final matchesType = _filterType == 'all' || tx.type == _filterType;
          final query = _searchQuery.toLowerCase();
          final matchesQuery =
              query.isEmpty ||
              tx.category.toLowerCase().contains(query) ||
              (tx.description?.toLowerCase().contains(query) ?? false) ||
              (tx.paymentMethod?.toLowerCase().contains(query) ?? false) ||
              tx.amount.toInt().toString().contains(query);
          return matchesType && matchesQuery;
        }).toList();

        if (filtered.isEmpty) {
          return GlassCard(
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
                    _searchQuery.isNotEmpty
                        ? 'Transaksi tidak ditemukan'
                        : 'Belum ada transaksi',
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Coba gunakan kata kunci pencarian yang lain.'
                        : 'Mulai dengan tambah manual atau scan struk pertama kamu.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption,
                  ),
                  if (_searchQuery.isEmpty) ...[
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
          );
        }

        return Column(
          children: filtered.asMap().entries.map((entry) {
            final idx = entry.key;
            final tx = entry.value;

            return AnimatedSlideFade(
              index: idx,
              child: TransactionCard(
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
                    ref
                        .read(transactionControllerProvider.notifier)
                        .deleteTransaction(tx.id);
                  }
                },
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, _) => GlassCard(
        child: Text(
          'Error memuat transaksi: $err',
          style: AppTypography.caption.copyWith(color: AppColors.expense),
        ),
      ),
    );
  }
}
