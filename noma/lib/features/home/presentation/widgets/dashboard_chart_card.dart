import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/floating_glass_card.dart';
import '../../../transaction/presentation/providers/transaction_provider.dart';

class DashboardChartCard extends ConsumerWidget {
  const DashboardChartCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(totalIncomeStreamProvider);
    final expenseAsync = ref.watch(totalExpenseStreamProvider);
    final transactionsAsync = ref.watch(recentTransactionsStreamProvider);

    final income = incomeAsync.valueOrNull ?? 0.0;
    final expense = expenseAsync.valueOrNull ?? 0.0;
    final total = income + expense;

    // Calculate percentage
    final incomePercent = total > 0 ? (income / total * 100).round() : 50;
    final expensePercent = total > 0 ? (expense / total * 100).round() : 50;

    return FloatingGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      floatDistance: 4.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Financial Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Analisis Keuangan', style: AppTypography.headingSmall),
                ],
              ),
              _buildStatusBadge(income, expense),
            ],
          ),
          const SizedBox(height: 20),

          // SECTION 1: Donut Chart (Pemasukan vs Pengeluaran)
          Row(
            children: [
              // Donut Chart
              SizedBox(
                height: 110,
                width: 110,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 36,
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            color: AppColors.income,
                            value: income > 0 ? income : (expense == 0 ? 1 : 0),
                            radius: 14,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            color: AppColors.expense,
                            value: expense > 0 ? expense : (income == 0 ? 1 : 0),
                            radius: 14,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ratio',
                            style: AppTypography.caption.copyWith(fontSize: 10),
                          ),
                          Text(
                            '$incomePercent% / $expensePercent%',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Legend breakdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendRow(
                      label: 'Pemasukan',
                      amount: income,
                      percent: incomePercent,
                      color: AppColors.income,
                    ),
                    const SizedBox(height: 12),
                    _buildLegendRow(
                      label: 'Pengeluaran',
                      amount: expense,
                      percent: expensePercent,
                      color: AppColors.expense,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: 14),

          // SECTION 2: 7-Day Mini Bar Chart (Tren 7 Hari Terakhir)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tren 7 Hari Terakhir', style: AppTypography.labelMedium),
              Row(
                children: [
                  _buildDotLegend('Masuk', AppColors.income),
                  const SizedBox(width: 10),
                  _buildDotLegend('Keluar', AppColors.expense),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 120,
            child: transactionsAsync.when(
              data: (transactions) => _build7DayBarChart(transactions),
              loading: () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
              error: (_, __) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(double income, double expense) {
    String label;
    Color color;

    if (income == 0 && expense == 0) {
      label = 'Belum ada data';
      color = AppColors.textMuted;
    } else if (income >= expense) {
      label = 'Keuangan Sehat';
      color = AppColors.income;
    } else {
      label = 'Perlu Hemat';
      color = AppColors.expense;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildLegendRow({
    required String label,
    required double amount,
    required int percent,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label ($percent%)', style: AppTypography.caption),
              Text(
                CurrencyFormatter.formatRupiahCompact(amount),
                style: AppTypography.labelLarge.copyWith(color: color, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDotLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.caption.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _build7DayBarChart(List dynamicTransactions) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));

    // Group transactions by day
    final Map<int, double> dailyIncome = {};
    final Map<int, double> dailyExpense = {};

    for (final tx in dynamicTransactions) {
      final txDate = DateTime.fromMillisecondsSinceEpoch(tx.transactionDate);
      final dayKey = DateTime(txDate.year, txDate.month, txDate.day).millisecondsSinceEpoch;

      if (tx.type == 'income') {
        dailyIncome[dayKey] = (dailyIncome[dayKey] ?? 0.0) + tx.amount;
      } else {
        dailyExpense[dayKey] = (dailyExpense[dayKey] ?? 0.0) + tx.amount;
      }
    }

    // Find max value for scaling
    double maxVal = 100000;
    for (final day in days) {
      final dayKey = day.millisecondsSinceEpoch;
      final inc = dailyIncome[dayKey] ?? 0.0;
      final exp = dailyExpense[dayKey] ?? 0.0;
      if (inc > maxVal) maxVal = inc;
      if (exp > maxVal) maxVal = exp;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.1,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = days[groupIndex];
              final dayName = DateFormat('E', 'id_ID').format(day);
              final isIncome = rodIndex == 0;
              final typeName = isIncome ? 'Pemasukan' : 'Pengeluaran';
              return BarTooltipItem(
                '$dayName\n$typeName: ${CurrencyFormatter.formatRupiahCompact(rod.toY)}',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) return const SizedBox();
                final day = days[index];
                final dayStr = DateFormat('E', 'id_ID').format(day);
                final isToday = day.day == now.day && day.month == now.month;

                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    dayStr,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: isToday ? AppColors.primary : AppColors.textMuted,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          final day = days[index];
          final dayKey = day.millisecondsSinceEpoch;
          final inc = dailyIncome[dayKey] ?? 0.0;
          final exp = dailyExpense[dayKey] ?? 0.0;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: inc,
                color: AppColors.income,
                width: 6,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: exp,
                color: AppColors.expense,
                width: 6,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }
}
