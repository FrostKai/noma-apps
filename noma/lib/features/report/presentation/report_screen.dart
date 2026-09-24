import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/report_export_service.dart';
import '../../../shared/providers/database_provider.dart';
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
  String _selectedPeriod = 'this_month';
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final range = _selectedRange();
    final reportAsync = ref.watch(reportDataStreamProvider(range));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Export laporan',
            onPressed: _exporting || reportAsync.valueOrNull == null
                ? null
                : () => _showExportOptions(reportAsync.valueOrNull!),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
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

                _buildReportSummaryGrid(context, report.summary),
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

  Future<void> _showExportOptions(ReportData report) async {
    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export Excel'),
              onTap: () => Navigator.pop(context, 'xlsx'),
            ),
          ],
        ),
      ),
    );
    if (format == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final range = _selectedRange();
      final service = ReportExportService(ref.read(databaseProvider));
      final name =
          'noma-laporan-${DateTime.now().millisecondsSinceEpoch}.$format';
      final file = File(p.join((await getTemporaryDirectory()).path, name));
      if (format == 'pdf') {
        const labels = {
          'this_month': 'Bulan Ini',
          'last_month': 'Bulan Lalu',
          'three_months': '3 Bulan',
          'six_months': '6 Bulan',
          'this_year': 'Tahun Ini',
          'all': 'Semua Waktu',
        };
        await service.exportPdf(file, labels[_selectedPeriod]!, report);
      } else {
        await service.exportExcel(
          file,
          startMs: range.startMs,
          endMs: range.endMs,
          count: report.summary.count,
        );
      }
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Noma');
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat laporan. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
    if (_selectedPeriod == 'three_months') {
      final start = DateTime(now.year, now.month - 2);
      final end = DateTime(now.year, now.month + 1);
      return (
        startMs: start.millisecondsSinceEpoch,
        endMs: end.millisecondsSinceEpoch,
      );
    }
    if (_selectedPeriod == 'six_months') {
      final start = DateTime(now.year, now.month - 5);
      final end = DateTime(now.year, now.month + 1);
      return (
        startMs: start.millisecondsSinceEpoch,
        endMs: end.millisecondsSinceEpoch,
      );
    }
    if (_selectedPeriod == 'this_year') {
      final start = DateTime(now.year);
      final end = DateTime(now.year + 1);
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
      {'key': 'three_months', 'label': '3 Bulan'},
      {'key': 'six_months', 'label': '6 Bulan'},
      {'key': 'this_year', 'label': 'Tahun Ini'},
      {'key': 'all', 'label': 'Semua Waktu'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = p['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : colors.glassSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : colors.glassBorder,
                  ),
                ),
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
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportSummaryGrid(
    BuildContext context,
    TransactionSummary summary,
  ) {
    final net = summary.balance;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Pemasukan',
                CurrencyFormatter.formatRupiahCompact(summary.income),
                Icons.arrow_downward_rounded,
                AppColors.income,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Pengeluaran',
                CurrencyFormatter.formatRupiahCompact(summary.expense),
                Icons.arrow_upward_rounded,
                AppColors.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Selisih',
                CurrencyFormatter.formatRupiahCompact(net),
                net >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                net >= 0 ? AppColors.income : AppColors.expense,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Transaksi',
                '${summary.count}',
                Icons.receipt_long_rounded,
                AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final colors = AppColorScheme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: color.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.headingMedium.copyWith(color: color),
          ),
        ],
      ),
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
