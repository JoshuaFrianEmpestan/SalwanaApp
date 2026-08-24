import 'package:flutter/material.dart';
import '../../models/order.dart' as model;
import '../constants/enums.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'order_status_visuals.dart';
import 'status_badge.dart';

class OrderListTile extends StatelessWidget {
  final model.Order order;
  final bool showConsumerName;
  final VoidCallback onTap;

  const OrderListTile({super.key, required this.order, this.showConsumerName = false, required this.onTap});

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
                    showConsumerName ? order.consumerName : order.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                StatusBadge(label: order.status.label, tone: orderStatusTone(order.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${order.items.length} item(s) · ${AppFormatters.currency(order.total)} · ${order.paymentMethod.label}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(AppFormatters.relative(order.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
          ],
        ),
      ),
    );
  }
}
