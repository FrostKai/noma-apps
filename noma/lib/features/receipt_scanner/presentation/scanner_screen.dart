import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
      debugPrint('Receipt scan failed: $e');

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
    final aiError = result['error'];
    if (aiError is String && aiError.trim().isNotEmpty) {
      return aiError;
    }

    final total = _extractTotalAmount(result);
    if (total <= 0) {
      return 'Total struk tidak terbaca. Silakan scan ulang dengan foto yang lebih jelas atau input manual.';
    }

    return null;
  }

  double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final cleaned = val.replaceAll(RegExp(r'[^\d]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  double _extractTotalAmount(Map<String, dynamic> result) {
    final items = (result['items'] as List?) ?? [];

    final rawTotal =
        result['total'] ??
        result['total_amount'] ??
        result['grand_total'] ??
        result['jumlah_total'] ??
        result['total_harga'] ??
        result['total_belanja'] ??
        result['amount'];

    var extractedTotal = _parseAmount(rawTotal);

    if (extractedTotal == 0.0 && items.isNotEmpty) {
      for (final item in items) {
        if (item is Map) {
          final itemPrice = _parseAmount(
            item['total_price'] ?? item['price'] ?? item['harga'],
          );
          extractedTotal += itemPrice;
        }
      }
    }

    return extractedTotal;
  }

  void _showConfirmationBottomSheet() {
    if (_scanResult == null) return;

    final storeName =
        (_scanResult!['store_name'] as String?) ??
        (_scanResult!['merchant'] as String?) ??
        (_scanResult!['toko'] as String?) ??
        'Struk Belanja';

    final items = (_scanResult!['items'] as List?) ?? [];

    final extractedTotal = _extractTotalAmount(_scanResult!);

    final category =
        (_scanResult!['category_suggestion'] as String?) ?? 'Belanja Harian';
    final dateStr = (_scanResult!['date'] as String?) ?? '';

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
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.income,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hasil Pemindaian Struk AI',
                    style: AppTypography.headingSmall,
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
                          CurrencyFormatter.formatRupiah(extractedTotal),
                          style: AppTypography.amountLarge.copyWith(
                            color: AppColors.expense,
                          ),
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

              // Items breakdown if available
              if (items.isNotEmpty) ...[
                Text(
                  'Rincian Item (${items.length}):',
                  style: AppTypography.labelMedium,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 130),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final name = (item['name'] as String?) ?? 'Item';
                      final price = _parseAmount(
                        item['total_price'] ?? item['price'] ?? item['harga'],
                      );
                      final qty = (item['quantity'] as num?)?.toInt() ?? 1;

                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$qty x $name',
                              style: AppTypography.bodySmall,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatRupiah(price),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pemindaian Struk AI', style: AppTypography.headingMedium),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
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
                            style: AppTypography.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Nomi AI akan mengekstrak toko, tanggal, & total secara otomatis',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),

                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: _buildScanGuideOverlay(),
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
              _buildScanErrorCard(),
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

  Widget _buildScanGuideOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanErrorCard() {
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
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _lastScanError!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
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
