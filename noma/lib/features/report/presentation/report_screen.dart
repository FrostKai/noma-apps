import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_color_scheme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../transaction/data/transaction_repository.dart';
import '../../transaction/presentation/providers/transaction_provider.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  int _touchedPieIndex = -1;
  String _selectedPeriod = 'this_month'; // 'this_month', 'last_month', 'all'

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final range = _selectedRange();
    final reportAsync = ref.watch(reportDataStreamProvider(range));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Laporan & Statistik',
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
      body: reportAsync.when(
        data: (report) {
          final income = report.summary.income;
          final expense = report.summary.expense;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period Filter Selector Bar
                _buildPeriodFilterSelector(context),
                const SizedBox(height: 20),

                // Overview Cards (Income vs Expense)
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        borderColor: AppColors.income.withValues(alpha: 0.4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_downward_rounded,
                                  color: AppColors.income,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Pemasukan',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              CurrencyFormatter.formatRupiahCompact(income),
                              style: AppTypography.headingMedium.copyWith(
                                color: AppColors.income,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        borderColor: AppColors.expense.withValues(alpha: 0.4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: AppColors.expense,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Pengeluaran',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              CurrencyFormatter.formatRupiahCompact(expense),
                              style: AppTypography.headingMedium.copyWith(
                                color: AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bar Chart Comparison Section
                Text(
                  'Perbandingan Keuangan',
                  style: AppTypography.labelLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    height: 200,
                    child: (income == 0 && expense == 0)
                        ? Center(
                            child: Text(
                              'Belum ada data untuk ditampilkan di grafik',
                              style: AppTypography.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          )
                        : BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (income > expense ? income : expense) * 1.2,
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                show: true,
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      switch (value.toInt()) {
                                        case 0:
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Text(
                                              'Pemasukan',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                  ),
                                            ),
                                          );
                                        case 1:
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Text(
                                              'Pengeluaran',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                    color: colors.textSecondary,
                                                  ),
                                            ),
                                          );
                                        default:
                                          return const SizedBox.shrink();
                                      }
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: false),
                              barGroups: [
                                BarChartGroupData(
                                  x: 0,
                                  barRods: [
                                    BarChartRodData(
                                      toY: income,
                                      color: AppColors.income,
                                      width: 32,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: expense,
                                      color: AppColors.expense,
                                      width: 32,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Expense Breakdown by Category (Donut Chart)
                Text(
                  'Pengeluaran Berdasarkan Kategori',
                  style: AppTypography.labelLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildExpenseCategoryPieChart(
                  context,
                  report.expenseCategories,
                  expense,
                ),
                const SizedBox(height: 24),

                Text(
                  'Insight Barang & Toko',
                  style: AppTypography.labelLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildReceiptInsightCard(
                  context,
                  report.topReceiptItems,
                  report.topMerchants,
                ),
                const SizedBox(height: 115),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ),
      ),
    );
  }

  SummaryRangeArgs _selectedRange() {
    final now = DateTime.now();
    if (_selectedPeriod == 'this_month') {
      final start = DateTime(now.year, now.month);
      final end = DateTime(now.year, now.month + 1);
      return (
        startMs: start.millisecondsSinceEpoch,
        endMs: end.millisecondsSinceEpoch,
      );
    }
    if (_selectedPeriod == 'last_month') {
      final start = DateTime(now.year, now.month - 1);
      final end = DateTime(now.year, now.month);
      return (
        startMs: start.millisecondsSinceEpoch,
        endMs: end.millisecondsSinceEpoch,
      );
    }
    return (startMs: null, endMs: null);
  }

  Widget _buildPeriodFilterSelector(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final periods = [
      {'key': 'this_month', 'label': 'Bulan Ini'},
      {'key': 'last_month', 'label': 'Bulan Lalu'},
      {'key': 'all', 'label': 'Semua Waktu'},
    ];

    return Row(
      children: periods.map((p) {
        final isSelected = _selectedPeriod == p['key'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriod = p['key']!;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : colors.glassSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : colors.glassBorder,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    p['label']!,
                    style: AppTypography.caption.copyWith(
                      color: isSelected ? Colors.white : colors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpenseCategoryPieChart(
    BuildContext context,
    List<CategoryTotal> categoryTotals,
    double totalExpense,
  ) {
    final colors = AppColorScheme.of(context);
    if (categoryTotals.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            'Belum ada transaksi pengeluaran pada periode ini.',
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }

    final palette = [
      AppColors.expense,
      AppColors.primary,
      AppColors.warning,
      AppColors.income,
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFF64748B),
    ];

    int colorIndex = 0;
    final sections = categoryTotals.map((entry) {
      final color = palette[colorIndex % palette.length];
      colorIndex++;
      final isTouched = colorIndex - 1 == _touchedPieIndex;
      final double fontSize = isTouched ? 16.0 : 12.0;
      final double radius = isTouched ? 60.0 : 50.0;

      final pct = totalExpense > 0
          ? ((entry.total / totalExpense) * 100).toStringAsFixed(0)
          : '0';

      return PieChartSectionData(
        color: color,
        value: entry.total,
        title: '$pct%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedPieIndex = -1;
                        return;
                      }
                      _touchedPieIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: colors.glassBorder),
          const SizedBox(height: 8),

          // Category Breakdown Legend List
          Column(
            children: categoryTotals.asMap().entries.map((indexed) {
              final idx = indexed.key;
              final entry = indexed.value;
              final color = palette[idx % palette.length];
              final percentage = totalExpense > 0
                  ? ((entry.total / totalExpense) * 100).toStringAsFixed(1)
                  : '0';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.name,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${CurrencyFormatter.formatRupiah(entry.total)} ($percentage%)',
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptInsightCard(
    BuildContext context,
    List<ReceiptItemTotal> topItems,
    List<CategoryTotal> topMerchants,
  ) {
    final colors = AppColorScheme.of(context);

    if (topItems.isEmpty && topMerchants.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Belum ada detail item struk pada periode ini.',
          style: AppTypography.caption.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topItems.isNotEmpty) ...[
            Text(
              'Barang Paling Banyak Menghabiskan Uang',
              style: AppTypography.labelMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...topItems.map((entry) {
              final quantity = entry.quantity;
              return _buildInsightRow(
                context,
                entry.name,
                '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)}x',
                CurrencyFormatter.formatRupiah(entry.total),
              );
            }),
          ],
          if (topItems.isNotEmpty && topMerchants.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: colors.glassBorder),
            const SizedBox(height: 8),
          ],
          if (topMerchants.isNotEmpty) ...[
            Text(
              'Toko/Merchant Terbesar',
              style: AppTypography.labelMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...topMerchants.map((entry) {
              return _buildInsightRow(
                context,
                entry.name,
                'Total',
                CurrencyFormatter.formatRupiah(entry.total),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightRow(
    BuildContext context,
    String title,
    String subtitle,
    String amount,
  ) {
    final colors = AppColorScheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: AppTypography.labelMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
