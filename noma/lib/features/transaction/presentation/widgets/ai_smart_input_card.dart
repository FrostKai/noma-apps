import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_color_scheme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/api_key_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/providers/ai_service_provider.dart';
import '../../../../shared/widgets/ai_key_setup_modal.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../receipt_scanner/domain/receipt_review_utils.dart';
import '../add_transaction_screen.dart';

class AiSmartInputCard extends ConsumerStatefulWidget {
  const AiSmartInputCard({super.key});

  @override
  ConsumerState<AiSmartInputCard> createState() => _AiSmartInputCardState();
}

class _AiSmartInputCardState extends ConsumerState<AiSmartInputCard> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseWithAi() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final hasKey = await ApiKeyService.hasValidApiKey();
    if (!hasKey) {
      if (!mounted) return;
      AiKeySetupModal.show(context, onKeySaved: () => _parseWithAi());
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final aiService = ref.read(geminiApiServiceProvider);
      final result = await aiService.parseNaturalText(text);
      final items = ReceiptReviewUtils.extractReceiptItems(
        (result['items'] as List?) ?? const [],
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _textController.clear();
      });

      // Construct a pre-filled transaction model from AI output
      final parsedTx = Transaction(
        id: 0,
        type: (result['type'] as String?) ?? 'expense',
        amount: ReceiptReviewUtils.extractTotalAmount(result),
        category: (result['category'] as String?) ?? 'Makanan & Minuman',
        description: result['description'] as String?,
        source: 'ai_text',
        paymentMethod: result['payment_method'] as String?,
        receiptImagePath: null,
        transactionDate: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Open Add Transaction Screen with AI pre-filled data
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddTransactionScreen(
            initialTransaction: parsedTx,
            initialItems: items,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (e.toString().contains('API Key')) {
        AiKeySetupModal.show(context, onKeySaved: () => _parseWithAi());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI gagal memproses: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      borderRadius: 18,
      borderColor: AppColors.primary.withValues(alpha: 0.45),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.glassBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Teks',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_isLoading)
                Text(
                  'Memproses...',
                  style: AppTypography.caption.copyWith(
                    color: colors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
            decoration: BoxDecoration(
              color: colors.glassSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !_isLoading,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Beli kopi 25rb qris',
                      hintStyle: AppTypography.caption.copyWith(
                        color: colors.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _parseWithAi(),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _isLoading ? null : _parseWithAi,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bisa pakai rincian item, misal: Indomie 3x 3500, susu 12000.',
            style: AppTypography.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
