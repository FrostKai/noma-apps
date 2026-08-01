import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_text_field.dart';
import 'providers/category_controller.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  String _filterType = 'all'; // 'all', 'expense', 'income'

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    String categoryType = 'expense';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.glassBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Tambah Kategori Baru', style: AppTypography.headingMedium),
                  const SizedBox(height: 16),

                  // Category Type Selector
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Pengeluaran')),
                          selected: categoryType == 'expense',
                          selectedColor: AppColors.expense,
                          onSelected: (val) {
                            if (val) setModalState(() => categoryType = 'expense');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Pemasukan')),
                          selected: categoryType == 'income',
                          selectedColor: AppColors.income,
                          onSelected: (val) {
                            if (val) setModalState(() => categoryType = 'income');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Name
                  GlassTextField(
                    controller: nameController,
                    labelText: 'Nama Kategori',
                    hintText: 'Misal: Langganan Streaming',
                    prefixIcon: Icons.category_rounded,
                  ),
                  const SizedBox(height: 24),

                  GlassButton(
                    label: 'Simpan Kategori',
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;

                      final navigator = Navigator.of(modalContext);

                      final success = await ref
                          .read(categoryControllerProvider.notifier)
                          .addCategory(
                            name: name,
                            type: categoryType,
                            color: categoryType == 'income' ? '#10B981' : '#F43F5E',
                          );

                      if (success) {
                        navigator.pop();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Manajemen Kategori', style: AppTypography.headingMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip('Semua', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Pengeluaran', 'expense'),
                const SizedBox(width: 8),
                _buildFilterChip('Pemasukan', 'income'),
              ],
            ),
          ),

          // Categories List
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                final filtered = categories.where((c) {
                  if (_filterType == 'all') return true;
                  return c.type == _filterType || c.type == 'both';
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Tidak ada kategori ditemukan',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final cat = filtered[index];
                    final isIncome = cat.type == 'income';

                    return GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isIncome
                                  ? AppColors.income.withValues(alpha: 0.2)
                                  : AppColors.expense.withValues(alpha: 0.2),
                              border: Border.all(
                                color: isIncome
                                    ? AppColors.income.withValues(alpha: 0.4)
                                    : AppColors.expense.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(
                              isIncome
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: isIncome ? AppColors.income : AppColors.expense,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cat.name, style: AppTypography.labelLarge),
                                const SizedBox(height: 2),
                                Text(
                                  isIncome ? 'Pemasukan' : 'Pengeluaran',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          if (cat.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.glassSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: Text('Default', style: AppTypography.caption),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense, size: 20),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Hapus Kategori?'),
                                    content: Text('Yakin ingin menghapus kategori "${cat.name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Batal'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Hapus', style: TextStyle(color: AppColors.expense)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  ref.read(categoryControllerProvider.notifier).deleteCategory(cat.id);
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Kategori Baru', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.glassSurface,
      side: BorderSide(
        color: isSelected ? Colors.transparent : AppColors.glassBorder,
      ),
      labelStyle: AppTypography.caption.copyWith(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filterType = value;
          });
        }
      },
    );
  }
}
