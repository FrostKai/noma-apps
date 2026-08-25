import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_color_scheme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/transaction_repository.dart';
import 'add_transaction_screen.dart';
import 'providers/transaction_provider.dart';
import 'widgets/transaction_card.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  String _searchQuery = '';
  String _filterType = 'all';
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
    final colors = AppColorScheme.of(context);
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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Transaksi',
          style: AppTypography.headingMedium.copyWith(
            color: colors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () {
          return ref
              .read(transactionHistoryControllerProvider(historyArgs).notifier)
              .loadInitial();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              sliver: SliverList.list(
                children: [
                  _buildMonthSelector(context),
                  const SizedBox(height: 12),
                  _buildSearchAndFilterBar(context),
                ],
              ),
            ),
            _TransactionHistorySliver(
              historyArgs: historyArgs,
              searchQuery: _searchQuery,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
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
            hintText: 'Cari transaksi (kategori, catatan, metode bayar)...',
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
