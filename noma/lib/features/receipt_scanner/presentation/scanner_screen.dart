import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_color_scheme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_key_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/ai_service_provider.dart';
import '../../../shared/widgets/ai_key_setup_modal.dart';
import '../../../shared/widgets/ai_thinking_widget.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../domain/receipt_review_utils.dart';
import '../../transaction/data/transaction_repository.dart';
import '../../transaction/presentation/providers/transaction_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imagePath;
  bool _isScanning = false;
  Map<String, dynamic>? _scanResult;
  String? _lastScanError;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imagePath = picked.path;
          _scanResult = null;
          _lastScanError = null;
        });
        _processReceiptWithAi();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil gambar: $e'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  Future<void> _processReceiptWithAi() async {
    if (_imageBytes == null) return;

    final geminiKey = await ApiKeyService.getGeminiApiKey();
    if (ApiKeyService.sanitizeKey(geminiKey).isEmpty) {
      if (!mounted) return;
      AiKeySetupModal.show(context, onKeySaved: () => _processReceiptWithAi());
      return;
    }

    setState(() {
      _isScanning = true;
      _lastScanError = null;
    });

    try {
      final aiService = ref.read(geminiApiServiceProvider);
      final result = await aiService.scanReceiptImage(_imageBytes!);

      if (!mounted) return;

      final validationError = _validateScanResult(result);
      if (validationError != null) {
        setState(() {
          _isScanning = false;
          _scanResult = null;
          _lastScanError = validationError;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: AppColors.expense,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      setState(() {
        _isScanning = false;
        _scanResult = result;
      });

      _showConfirmationBottomSheet();
    } catch (e) {
      if (!mounted) return;
      final userMessage = _friendlyScanErrorMessage(e);
      debugPrint('Receipt scan failed: ${e.runtimeType}');

      setState(() {
        _isScanning = false;
        _lastScanError = userMessage;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: AppColors.expense,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Input Manual',
            textColor: Colors.white,
            onPressed: _openManualInput,
          ),
        ),
      );
    }
  }

  String _friendlyScanErrorMessage(Object error) {
    final raw = error.toString().replaceAll('Exception: ', '');

    if (raw.contains('API Key') ||
        raw.contains('API_KEY_INVALID') ||
        raw.contains('invalid_api_key')) {
      return 'Gemini API Key belum valid. Periksa kembali key di Pengaturan.';
    }

    if (raw.contains('429') ||
        raw.contains('Quota') ||
        raw.contains('RESOURCE_EXHAUSTED')) {
      return 'Kuota Gemini sedang habis atau terlalu banyak percobaan. Coba lagi beberapa saat nanti.';
    }

    if (raw.contains('timeout') ||
        raw.contains('terhubung') ||
        raw.contains('connection')) {
      return 'Koneksi ke Gemini belum stabil. Periksa internet lalu coba scan ulang.';
    }

    if (raw.contains('not found') || raw.contains('not supported')) {
      return 'Model Gemini untuk scan belum tersedia di key ini. Coba ganti Gemini API Key atau input manual dulu.';
    }

    return 'Scan belum berhasil. Coba foto ulang dengan struk lebih terang dan total terlihat jelas.';
  }

  void _openManualInput() {
    context.push(AppRoutes.addTransaction);
  }

  String? _validateScanResult(Map<String, dynamic> result) {
    return ReceiptReviewUtils.validateScanResult(result);
  }

  Future<TransactionItemInput?> _showReceiptItemDialog(
    BuildContext context, {
    TransactionItemInput? initialItem,
  }) async {
    final nameController = TextEditingController(text: initialItem?.name ?? '');
    final quantityController = TextEditingController(
      text: initialItem == null ? '1' : initialItem.quantity.toString(),
    );
    final unitPriceController = TextEditingController(
      text: initialItem?.unitPrice == null
          ? ''
          : initialItem!.unitPrice!.toInt().toString(),
    );
    final totalController = TextEditingController(
      text: initialItem == null
          ? ''
          : initialItem.totalPrice.toInt().toString(),
    );

    final result = await showDialog<TransactionItemInput>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(initialItem == null ? 'Tambah Item' : 'Edit Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama barang'),
              ),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah'),
              ),
              TextField(
                controller: unitPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga satuan'),
              ),
              TextField(
                controller: totalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total harga'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final quantity = ReceiptReviewUtils.parseQuantity(
                  quantityController.text,
                );
                final unitPrice = ReceiptReviewUtils.parseAmount(
                  unitPriceController.text,
                );
                final totalPrice = ReceiptReviewUtils.parseAmount(
                  totalController.text,
                );

                final item = ReceiptReviewUtils.normalizeItem(
                  name: name,
                  quantity: quantity,
                  unitPrice: unitPrice,
                  totalPrice: totalPrice,
                );

                if (item.name.isEmpty || item.totalPrice <= 0) return;

                Navigator.pop(context, item);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    totalController.dispose();
    return result;
  }

  void _showConfirmationBottomSheet() {
    if (_scanResult == null) return;
    final colors = AppColorScheme.of(context);
    final review = ReceiptReviewUtils.fromScanResult(_scanResult!);
    final storeName = review.merchant;
    final receiptItems = [...review.items];
    final extractedTotal = review.total;
    final category = review.category;
    final dateStr = review.dateText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final itemTotal = ReceiptReviewUtils.totalItems(receiptItems);
            final difference = ReceiptReviewUtils.totalDifference(
              extractedTotal,
              receiptItems,
            );
            final hasMismatch = ReceiptReviewUtils.hasTotalMismatch(
              extractedTotal,
              receiptItems,
            );

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
                        color: colors.glassBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.income,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hasil Pemindaian Struk AI',
                        style: AppTypography.headingSmall.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Summary Card (Clean static display as original)
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Toko/Merchant',
                              style: AppTypography.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              storeName,
                              style: AppTypography.labelLarge.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Divider(color: colors.glassBorder),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tanggal',
                              style: AppTypography.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              dateStr.isEmpty ? 'Hari ini' : dateStr,
                              style: AppTypography.labelLarge.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Divider(color: colors.glassBorder),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Belanja',
                              style: AppTypography.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.formatRupiah(extractedTotal),
                              style: AppTypography.amountLarge.copyWith(
                                color: AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                        Divider(color: colors.glassBorder),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Saran Kategori',
                              style: AppTypography.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            Chip(
                              label: Text(
                                category,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${receiptItems.length} item terdeteksi',
                                style: AppTypography.labelLarge.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (receiptItems.isNotEmpty)
                                Text(
                                  'Total item ${CurrencyFormatter.formatRupiah(itemTotal)}',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _showReceiptItemsEditor(
                              modalContext,
                              receiptItems,
                            );
                            setModalState(() {});
                          },
                          child: Text(
                            receiptItems.isEmpty
                                ? 'Tambah Item'
                                : 'Lihat/Edit Item',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasMismatch) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Total item berbeda dengan total transaksi. Selisih ${CurrencyFormatter.formatRupiah(difference.abs())}.',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Action Buttons Row (Scan Ulang & Simpan Transaksi)
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          label: 'Scan Ulang',
                          icon: Icons.refresh_rounded,
                          variant: GlassButtonVariant.warning,
                          height: 48,
                          onPressed: () {
                            Navigator.of(modalContext).pop();
                            _processReceiptWithAi();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: GlassButton(
                          label: 'Simpan Transaksi',
                          icon: Icons.save_rounded,
                          variant: GlassButtonVariant.income,
                          height: 48,
                          onPressed: () async {
                            final navigator = Navigator.of(modalContext);
                            final screenNavigator = Navigator.of(context);

                            DateTime txDate = DateTime.now();
                            if (dateStr.isNotEmpty) {
                              try {
                                txDate = DateTime.parse(dateStr);
                              } catch (_) {}
                            }

                            final success = await ref
                                .read(transactionControllerProvider.notifier)
                                .addTransaction(
                                  type: 'expense',
                                  amount: extractedTotal,
                                  category: category,
                                  description: 'Struk $storeName',
                                  source: 'receipt_scan',
                                  paymentMethod: 'Tunai',
                                  receiptImagePath: kIsWeb ? null : _imagePath,
                                  transactionDate: txDate,
                                  items: receiptItems,
                                );

                            if (success) {
                              navigator.pop();
                              screenNavigator.pop();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showReceiptItemsEditor(
    BuildContext context,
    List<TransactionItemInput> receiptItems,
  ) {
    final colors = AppColorScheme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Edit Item Struk',
                            style: AppTypography.headingSmall.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: receiptItems.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Belum ada item.',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: receiptItems.length,
                              separatorBuilder: (_, __) =>
                                  Divider(color: colors.glassBorder),
                              itemBuilder: (context, index) {
                                final item = receiptItems[index];
                                final unitText = item.unitPrice == null
                                    ? null
                                    : CurrencyFormatter.formatRupiah(
                                        item.unitPrice!,
                                      );

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    item.name,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    unitText == null
                                        ? '${_formatQuantity(item.quantity)} item'
                                        : '${_formatQuantity(item.quantity)} x $unitText',
                                    style: AppTypography.caption.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        CurrencyFormatter.formatRupiah(
                                          item.totalPrice,
                                        ),
                                        style: AppTypography.caption.copyWith(
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          final edited =
                                              await _showReceiptItemDialog(
                                                context,
                                                initialItem: item,
                                              );
                                          if (edited != null) {
                                            setSheetState(
                                              () =>
                                                  receiptItems[index] = edited,
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 18,
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          setSheetState(
                                            () => receiptItems.removeAt(index),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppColors.expense,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    GlassButton(
                      label: 'Tambah Item',
                      icon: Icons.add_rounded,
                      variant: GlassButtonVariant.secondary,
                      height: 46,
                      onPressed: () async {
                        final item = await _showReceiptItemDialog(context);
                        if (item != null) {
                          setSheetState(() => receiptItems.add(item));
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatQuantity(double quantity) {
    return quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Pemindaian Struk AI',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Preview / Camera Box
            GlassCard(
              height: 380,
              width: double.infinity,
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  if (_imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        _imageBytes!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 64,
                            color: AppColors.primary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Posisikan Struk Belanja di Dalam Kotak',
                            style: AppTypography.labelLarge.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Nomi AI akan mengekstrak toko, tanggal, & total secara otomatis',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: _buildScanGuideOverlay(context),
                  ),

                  // Futuristic AI Scanning & Thinking Animation Overlay
                  if (_isScanning)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.65),
                        padding: const EdgeInsets.all(24),
                        child: const Center(
                          child: AiThinkingWidget(
                            text: 'Nomi AI sedang membaca & mengekstrak struk',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_lastScanError != null) ...[
              _buildScanErrorCard(context),
              const SizedBox(height: 16),
            ],

            // Scan Ulang Button (Appears when photo is selected)
            if (_imageBytes != null) ...[
              GlassButton(
                label: 'Scan Ulang',
                icon: Icons.auto_awesome_rounded,
                variant: GlassButtonVariant.income,
                height: 48,
                onPressed: _isScanning ? null : _processReceiptWithAi,
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons (Kamera / Galeri)
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: _imageBytes != null ? 'Foto Ulang' : 'Kamera',
                    icon: Icons.camera_alt_rounded,
                    variant: GlassButtonVariant.primary,
                    onPressed: _isScanning
                        ? null
                        : () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: 'Galeri HP',
                    icon: Icons.photo_library_rounded,
                    variant: GlassButtonVariant.secondary,
                    onPressed: _isScanning
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassButton(
              label: 'Input Manual',
              icon: Icons.edit_note_rounded,
              variant: GlassButtonVariant.outline,
              height: 48,
              onPressed: _openManualInput,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanGuideOverlay(BuildContext context) {
    final colors = AppColorScheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColorScheme.isLight(context)
            ? Colors.white.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.tips_and_updates_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pastikan nama toko, daftar item, dan total belanja terlihat jelas.',
              style: AppTypography.caption.copyWith(
                color: colors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanErrorCard(BuildContext context) {
    final colors = AppColorScheme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.expense.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.expense,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Scan belum berhasil',
                style: AppTypography.labelLarge.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _lastScanError!,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: 'Scan Ulang',
                  icon: Icons.refresh_rounded,
                  variant: GlassButtonVariant.warning,
                  height: 42,
                  onPressed: _imageBytes == null || _isScanning
                      ? null
                      : _processReceiptWithAi,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(
                  label: 'Input Manual',
                  icon: Icons.edit_note_rounded,
                  variant: GlassButtonVariant.outline,
                  height: 42,
                  onPressed: _openManualInput,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
