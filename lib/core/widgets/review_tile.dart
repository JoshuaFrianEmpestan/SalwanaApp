import 'package:flutter/material.dart';
import '../../models/store_review.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class StarRow extends StatelessWidget {
  final int rating;
  final double size;
  const StarRow({super.key, required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(i <= rating ? Icons.star_rounded : Icons.star_border_rounded, size: size, color: AppColors.warning),
      ],
    );
  }
}

class ReviewTile extends StatelessWidget {
  final StoreReview review;
  final bool isStoreOwner;
  final bool isAuthor;
  final VoidCallback? onEdit;
  final VoidCallback? onRespond;
  final VoidCallback? onReport;

  const ReviewTile({
    super.key,
    required this.review,
    this.isStoreOwner = false,
    this.isAuthor = false,
    this.onEdit,
    this.onRespond,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(review.consumerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              StarRow(rating: review.rating),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(4)),
                child: const Text('Verified Purchase', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.success)),
              ),
              const SizedBox(width: 8),
              Text(AppFormatters.relative(review.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
            ],
          ),
          const SizedBox(height: 8),
          Text(review.feedback, style: const TextStyle(fontSize: 13, height: 1.4)),
          if (review.merchantResponse != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Merchant Response', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(review.merchantResponse!, style: const TextStyle(fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
          if (isAuthor || (isStoreOwner && review.merchantResponse == null) || onReport != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (isAuthor && review.isEditable && onEdit != null)
                  TextButton(onPressed: onEdit, child: const Text('Edit', style: TextStyle(fontSize: 12))),
                if (isStoreOwner && review.merchantResponse == null && onRespond != null)
                  TextButton(onPressed: onRespond, child: const Text('Respond', style: TextStyle(fontSize: 12))),
                const Spacer(),
                if (onReport != null)
                  TextButton(
                    onPressed: onReport,
                    child: Text(review.reported ? 'Reported' : 'Report', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
