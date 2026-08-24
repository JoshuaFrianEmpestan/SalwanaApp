import 'package:flutter/material.dart';
import '../../models/restock_request.dart';
import '../constants/enums.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'restock_status_visuals.dart';
import 'status_badge.dart';

class RestockRequestTile extends StatelessWidget {
  final RestockRequest request;
  final bool showSupplierName;
  final VoidCallback onTap;

  const RestockRequestTile({super.key, required this.request, this.showSupplierName = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    showSupplierName ? request.supplierName : request.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                StatusBadge(label: request.status.label, tone: restockStatusTone(request.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${request.items.length} product(s) · est. ${AppFormatters.currency(request.estimatedTotal)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(AppFormatters.relative(request.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
          ],
        ),
      ),
    );
  }
}
