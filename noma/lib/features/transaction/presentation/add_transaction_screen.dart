import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_color_scheme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_text_field.dart';
import 'providers/transaction_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? initialTransaction;

  const AddTransactionScreen({super.key, this.initialTransaction});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late String _type; // 'expense' or 'income'
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _selectedCategory;
  String _selectedPaymentMethod = 'Tunai';
  DateTime _selectedDate = DateTime.now();

  final List<String> _paymentMethods = [
    'Tunai',
    'Gopay',
    'OVO',
    'ShopeePay',
    'Transfer BCA',
    'Transfer Mandiri',
    'Transfer BRI',
    'Kartu Kredit',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final tx = widget.initialTransaction!;
      _type = tx.type;
      final rawAmount = tx.amount.toInt();
      _amountController.text = rawAmount > 0 ? NumberFormat.decimalPattern('id_ID').format(rawAmount) : '';
      _descController.text = tx.description ?? '';
      _selectedCategory = tx.category;
      _selectedPaymentMethod = tx.paymentMethod ?? 'Tunai';
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(tx.transactionDate);
    } else {
      _type = 'expense';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  double get _parsedAmount {
    final clean = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final isLight = AppColorScheme.isLight(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isLight
                ? const ColorScheme.light(
                    primary: AppColors.primary,
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  )
                : const ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: AppColors.surface,
                    onSurface: AppColors.textPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  void _submit() async {
    final amount = _parsedAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal transaksi harus lebih dari 0'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori transaksi terlebih dahulu'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final controller = ref.read(transactionControllerProvider.notifier);

    final isActualEdit = widget.initialTransaction != null && widget.initialTransaction!.id != 0;

    if (isActualEdit) {
      final updated = widget.initialTransaction!.copyWith(
        type: _type,
        amount: amount,
        category: _selectedCategory!,
        description: Value(_descController.text.trim()),
        paymentMethod: Value(_selectedPaymentMethod),
        transactionDate: _selectedDate.millisecondsSinceEpoch,
      );
      final success = await controller.updateTransaction(updated);
      if (success && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      final source = widget.initialTransaction?.source ?? 'manual';
      final success = await controller.addTransaction(
        type: _type,
        amount: amount,
        category: _selectedCategory!,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        source: source,
        paymentMethod: _selectedPaymentMethod,
        transactionDate: _selectedDate,
      );
      if (success && mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final isEdit = widget.initialTransaction != null && widget.initialTransaction!.id != 0;
    final state = ref.watch(transactionControllerProvider);
    final categoriesAsync = _type == 'income'
        ? ref.watch(incomeCategoriesStreamProvider)
        : ref.watch(expenseCategoriesStreamProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Transaksi' : 'Tambah Transaksi',
          style: AppTypography.headingMedium.copyWith(color: colors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type Selector Pill Toggle
            _buildTypeToggle(context),
            const SizedBox(height: 24),

            // Amount Input Card
            _buildAmountCard(context),
            const SizedBox(height: 20),

            // Category Picker
            Text('Kategori', style: AppTypography.labelMedium.copyWith(color: colors.textSecondary)),
            const SizedBox(height: 8),
            _buildCategoryPicker(context, categoriesAsync),
            const SizedBox(height: 20),

            // Payment Method Selector
            Text('Metode Pembayaran', style: AppTypography.labelMedium.copyWith(color: colors.textSecondary)),
            const SizedBox(height: 8),
            _buildPaymentMethodPicker(context),
            const SizedBox(height: 20),

            // Date Picker Card
            Text('Tanggal Transaksi', style: AppTypography.labelMedium.copyWith(color: colors.textSecondary)),
            const SizedBox(height: 8),
            GlassCard(
              onTap: _selectDate,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        DateFormatter.formatFullDate(_selectedDate),
                        style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
                      ),
                    ],
                  ),
                  Icon(Icons.edit_calendar_rounded, color: colors.textSecondary, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Description Input
            GlassTextField(
              controller: _descController,
              labelText: 'Catatan / Deskripsi (Opsional)',
              hintText: 'Misal: Nasi Goreng Spesial Pakai Telur',
              prefixIcon: Icons.edit_note_rounded,
            ),
            const SizedBox(height: 32),

            // Submit Button
            GlassButton(
              label: isEdit ? 'Simpan Perubahan' : 'Simpan Transaksi',
              icon: Icons.check_circle_outline_rounded,
              variant: _type == 'income' ? GlassButtonVariant.income : GlassButtonVariant.expense,
              isLoading: state.isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(BuildContext context) {
    final colors = AppColorScheme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.glassSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _type = 'expense';
                  _selectedCategory = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _type == 'expense' ? AppColors.expense : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _type == 'expense'
                      ? [
                          BoxShadow(
                            color: AppColors.expense.withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: _type == 'expense' ? Colors.white : colors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pengeluaran',
                        style: AppTypography.labelLarge.copyWith(
                          color: _type == 'expense' ? Colors.white : colors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _type = 'income';
                  _selectedCategory = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _type == 'income' ? AppColors.income : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _type == 'income'
                      ? [
                          BoxShadow(
                            color: AppColors.income.withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 18,
                        color: _type == 'income' ? Colors.white : colors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pemasukan',
                        style: AppTypography.labelLarge.copyWith(
                          color: _type == 'income' ? Colors.white : colors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final accentColor = _type == 'income' ? AppColors.income : AppColors.expense;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      borderColor: accentColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nominal (${_type == 'income' ? 'Pemasukan' : 'Pengeluaran'})',
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Rp ',
                style: AppTypography.amountDisplay.copyWith(color: accentColor),
              ),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  onChanged: (val) => setState(() {}),
                  style: AppTypography.amountDisplay.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: colors.textMuted),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          if (_parsedAmount > 0) ...[
            Divider(color: colors.glassBorder),
            Text(
              CurrencyFormatter.formatRupiah(_parsedAmount),
              style: AppTypography.caption.copyWith(color: accentColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryPicker(BuildContext context, AsyncValue<List<Category>> categoriesAsync) {
    final colors = AppColorScheme.of(context);
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return GlassCard(
            child: Text(
              'Belum ada kategori tersedia.',
              style: AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
          );
        }

        // Auto select first category if null
        if (_selectedCategory == null && categories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedCategory = categories.first.name;
              });
            }
          });
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat.name;
            return ChoiceChip(
              label: Text(cat.name),
              selected: isSelected,
              selectedColor: _type == 'income' ? AppColors.income : AppColors.expense,
              backgroundColor: colors.glassSurface,
              side: BorderSide(
                color: isSelected ? Colors.transparent : colors.glassBorder,
              ),
              labelStyle: AppTypography.caption.copyWith(
                color: isSelected ? Colors.white : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = cat.name;
                  });
                }
              },
            );
          }).toList(),
        );
      },
      loading: () => const LinearProgressIndicator(color: AppColors.primary),
      error: (err, _) => Text('Error memuat kategori: $err', style: AppTypography.caption.copyWith(color: AppColors.expense)),
    );
  }

  Widget _buildPaymentMethodPicker(BuildContext context) {
    final colors = AppColorScheme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _paymentMethods.map((method) {
        final isSelected = _selectedPaymentMethod == method;
        return ChoiceChip(
          label: Text(method),
          selected: isSelected,
          selectedColor: AppColors.primary,
          backgroundColor: colors.glassSurface,
          side: BorderSide(
            color: isSelected ? Colors.transparent : colors.glassBorder,
          ),
          labelStyle: AppTypography.caption.copyWith(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedPaymentMethod = method;
              });
            }
          },
        );
      }).toList(),
    );
  }
}
