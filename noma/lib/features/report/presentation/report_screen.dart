import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/glass_card.dart';
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
    final transactionsAsync = ref.watch(allTransactionsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Laporan & Statistik', style: AppTypography.headingMedium),
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: transactionsAsync.when(
        data: (allTransactions) {
          final now = DateTime.now();

          // Filter transactions based on selected period
          final filteredTransactions = allTransactions.where((tx) {
            final txDate = DateTime.fromMillisecondsSinceEpoch(tx.transactionDate);
            if (_selectedPeriod == 'this_month') {
              return txDate.year == now.year && txDate.month == now.month;
            } else if (_selectedPeriod == 'last_month') {
              final lastMonth = DateTime(now.year, now.month - 1);
              return txDate.year == lastMonth.year && txDate.month == lastMonth.month;
            }
            return true; // 'all'
          }).toList();

          double income = 0;
          double expense = 0;

          for (final tx in filteredTransactions) {
            if (tx.type == 'income') {
              income += tx.amount;
            } else {
              expense += tx.amount;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period Filter Selector Bar
                _buildPeriodFilterSelector(),
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
                                const Icon(Icons.arrow_downward_rounded, color: AppColors.income, size: 18),
                                const SizedBox(width: 6),
                                Text('Pemasukan', style: AppTypography.caption),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              CurrencyFormatter.formatRupiahCompact(income),
                              style: AppTypography.headingMedium.copyWith(color: AppColors.income),
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
                                const Icon(Icons.arrow_upward_rounded, color: AppColors.expense, size: 18),
                                const SizedBox(width: 6),
                                Text('Pengeluaran', style: AppTypography.caption),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              CurrencyFormatter.formatRupiahCompact(expense),
                              style: AppTypography.headingMedium.copyWith(color: AppColors.expense),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bar Chart Comparison Section
                Text('Perbandingan Keuangan', style: AppTypography.labelLarge),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    height: 200,
                    child: (income == 0 && expense == 0)
                        ? Center(
                            child: Text(
                              'Belum ada data untuk ditampilkan di grafik',
                              style: AppTypography.caption,
                            ),
                          )
                        : BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (income > expense ? income : expense) * 1.2,
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                show: true,
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      switch (value.toInt()) {
                                        case 0:
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text('Pemasukan', style: AppTypography.caption),
                                          );
                                        case 1:
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text('Pengeluaran', style: AppTypography.caption),
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
                Text('Pengeluaran Berdasarkan Kategori', style: AppTypography.labelLarge),
                const SizedBox(height: 12),
                _buildExpenseCategoryPieChart(filteredTransactions, expense),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err', style: AppTypography.caption)),
      ),
    );
  }

  Widget _buildPeriodFilterSelector() {
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
                  color: isSelected ? AppColors.primary : AppColors.glassSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.glassBorder,
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
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildExpenseCategoryPieChart(List filteredTransactions, double totalExpense) {
    final expenses = filteredTransactions.where((t) => t.type == 'expense').toList();
    if (expenses.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            'Belum ada transaksi pengeluaran pada periode ini.',
            style: AppTypography.caption,
          ),
        ),
      );
    }

    // Aggregate expense amounts per category
    final Map<String, double> categoryTotals = {};
    for (final tx in expenses) {
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0.0) + tx.amount;
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
    final sections = categoryTotals.entries.map((entry) {
      final color = palette[colorIndex % palette.length];
      colorIndex++;
      final isTouched = colorIndex - 1 == _touchedPieIndex;
      final double fontSize = isTouched ? 16.0 : 12.0;
      final double radius = isTouched ? 60.0 : 50.0;

      final pct = totalExpense > 0 ? ((entry.value / totalExpense) * 100).toStringAsFixed(0) : '0';

      return PieChartSectionData(
        color: color,
        value: entry.value,
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
                      _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
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
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: 8),

          // Category Breakdown Legend List
          Column(
            children: categoryTotals.entries.map((entry) {
              final idx = categoryTotals.keys.toList().indexOf(entry.key);
              final color = palette[idx % palette.length];
              final percentage = totalExpense > 0
                  ? ((entry.value / totalExpense) * 100).toStringAsFixed(1)
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
                      child: Text(entry.key, style: AppTypography.bodySmall),
                    ),
                    Text(
                      '${CurrencyFormatter.formatRupiah(entry.value)} ($percentage%)',
                      style: AppTypography.labelMedium,
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
}
