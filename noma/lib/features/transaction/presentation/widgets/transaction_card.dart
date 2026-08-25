import 'package:flutter/material.dart';
import '../../../../core/constants/app_color_scheme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/glass_card.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  bool get isIncome => transaction.type == 'income';

  IconData get _icon {
    switch (transaction.category.toLowerCase()) {
      case 'makanan & minuman':
      case 'makanan':
        return Icons.fastfood_rounded;
      case 'belanja harian':
      case 'belanja':
        return Icons.shopping_bag_rounded;
      case 'transportasi':
        return Icons.directions_car_rounded;
      case 'tagihan & utilitas':
        return Icons.receipt_long_rounded;
      case 'hiburan':
        return Icons.sports_esports_rounded;
      case 'kesehatan':
        return Icons.medical_services_rounded;
      case 'gaji':
        return Icons.payments_rounded;
      case 'bonus & thr':
        return Icons.card_giftcard_rounded;
      case 'investasi':
        return Icons.trending_up_rounded;
      default:
        return isIncome
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final isLight = AppColorScheme.isLight(context);
    final date = DateTime.fromMillisecondsSinceEpoch(
      transaction.transactionDate,
    );
    final accentColor = isIncome ? AppColors.income : AppColors.expense;

    return GlassCard(
      onTap: onTap,
      enableBlur: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 10),
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.16),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Icon(_icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.category,
                        style: AppTypography.labelLarge.copyWith(
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (transaction.paymentMethod != null &&
                        transaction.paymentMethod!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: colors.glassSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.glassBorder),
                        ),
                        child: Text(
                          transaction.paymentMethod!,
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormatter.formatRelative(date),
                      style: AppTypography.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    if (transaction.description != null &&
                        transaction.description!.isNotEmpty) ...[
                      Text(
                        ' • ',
                        style: AppTypography.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          transaction.description!,
                          style: AppTypography.caption.copyWith(
                            color: colors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Amount & Delete action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}${CurrencyFormatter.formatRupiah(transaction.amount)}',
                style: AppTypography.labelLarge.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.textMuted,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
