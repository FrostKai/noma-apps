import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_key_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/providers/ai_service_provider.dart';
import '../../../shared/widgets/ai_key_setup_modal.dart';
import '../../../shared/widgets/ai_thinking_widget.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
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

    final hasKey = await ApiKeyService.hasValidApiKey();
    if (!hasKey) {
      if (!mounted) return;
      AiKeySetupModal.show(context, onKeySaved: () => _processReceiptWithAi());
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final aiService = ref.read(geminiApiServiceProvider);
      final result = await aiService.scanReceiptImage(_imageBytes!);

      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _scanResult = result;
      });

      _showConfirmationBottomSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
      });

      if (e.toString().contains('API Key')) {
        AiKeySetupModal.show(context, onKeySaved: () => _processReceiptWithAi());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses struk: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  void _showConfirmationBottomSheet() {
    if (_scanResult == null) return;

    final storeName = (_scanResult!['store_name'] as String?) ?? 'Toko/Merchant';

    double parseAmount(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        final cleaned = val.replaceAll(RegExp(r'[^\d]'), '');
        return double.tryParse(cleaned) ?? 0.0;
      }
      return 0.0;
    }

    final total = parseAmount(_scanResult!['total']);
    final category = (_scanResult!['category_suggestion'] as String?) ?? 'Belanja Harian';
    final dateStr = (_scanResult!['date'] as String?) ?? '';
    final items = (_scanResult!['items'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
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
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 24),
                  const SizedBox(width: 8),
                  Text('Hasil Pemindaian Struk AI', style: AppTypography.headingSmall),
                ],
              ),
              const SizedBox(height: 16),

              // Summary Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Toko/Merchant', style: AppTypography.caption),
                        Text(storeName, style: AppTypography.labelLarge),
                      ],
                    ),
                    const Divider(color: AppColors.glassBorder),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Belanja', style: AppTypography.caption),
                        Text(
                          CurrencyFormatter.formatRupiah(total),
                          style: AppTypography.amountLarge.copyWith(color: AppColors.expense),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.glassBorder),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Saran Kategori', style: AppTypography.caption),
                        Chip(
                          label: Text(category, style: AppTypography.caption),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Items breakdown if available
              if (items.isNotEmpty) ...[
                Text('Rincian Item (${items.length}):', style: AppTypography.labelMedium),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final name = (item['name'] as String?) ?? 'Item';
                      final price = (item['total_price'] as num?)?.toDouble() ?? 0.0;
                      final qty = (item['quantity'] as num?)?.toInt() ?? 1;

                      return Row(
                        children: [
                          Expanded(
                            child: Text('$qty x $name', style: AppTypography.bodySmall),
                          ),
                          Text(
                            CurrencyFormatter.formatRupiah(price),
                            style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Confirm and Save Button
              GlassButton(
                label: 'Konfirmasi & Simpan Transaksi',
                icon: Icons.save_rounded,
                variant: GlassButtonVariant.expense,
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
                        amount: total,
                        category: category,
                        description: 'Struk $storeName',
                        source: 'receipt_scan',
                        paymentMethod: 'Tunai',
                        receiptImagePath: kIsWeb ? null : _imagePath,
                        transactionDate: txDate,
                      );

                  if (success) {
                    navigator.pop();
                    screenNavigator.pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pemindaian Struk AI', style: AppTypography.headingMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
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
                            style: AppTypography.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Groq Cloud AI akan mengekstrak toko, tanggal, & total belanja secara otomatis',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),

                  // Futuristic AI Scanning & Thinking Animation Overlay
                  if (_isScanning)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.65),
                        padding: const EdgeInsets.all(24),
                        child: const Center(
                          child: AiThinkingWidget(
                            text: 'Groq Cloud AI sedang membaca & mengekstrak struk',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons (Kamera / Galeri)
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'Kamera',
                    icon: Icons.camera_alt_rounded,
                    variant: GlassButtonVariant.primary,
                    onPressed: _isScanning ? null : () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: 'Galeri HP',
                    icon: Icons.photo_library_rounded,
                    variant: GlassButtonVariant.secondary,
                    onPressed: _isScanning ? null : () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
