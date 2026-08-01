import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/api_key_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/providers/ai_service_provider.dart';
import '../../../../shared/widgets/ai_key_setup_modal.dart';
import '../../../../shared/widgets/floating_glass_card.dart';
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

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _textController.clear();
      });

      // Construct a pre-filled transaction model from AI output
      final parsedTx = Transaction(
        id: 0,
        type: (result['type'] as String?) ?? 'expense',
        amount: (result['amount'] as num?)?.toDouble() ?? 0.0,
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
          builder: (context) => AddTransactionScreen(initialTransaction: parsedTx),
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
    return FloatingGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: AppColors.primary.withValues(alpha: 0.45),
      floatDistance: 5.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Catat Pintar via Teks AI',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: !_isLoading,
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    hintText: "Contoh: 'Beli nasi goreng 25rb pake OVO'",
                    hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _parseWithAi(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _isLoading ? null : _parseWithAi,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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
        ],
      ),
    );
  }
}
