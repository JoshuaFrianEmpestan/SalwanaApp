import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/reservation.dart';
import '../constants/enums.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'reservation_status_visuals.dart';
import 'status_badge.dart';

class ReservationListTile extends StatelessWidget {
  final Reservation reservation;
  final bool showConsumerName;
  final VoidCallback onTap;

  const ReservationListTile({super.key, required this.reservation, this.showConsumerName = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: reservation.productImageUrl != null
                    ? CachedNetworkImage(fadeInDuration: Duration.zero, useOldImageOnUrlChange: true, placeholder: (ctx, url) => Container(color: AppColors.neutralBg), errorWidget: (ctx, url, err) => Container(color: AppColors.neutralBg, child: const Icon(Icons.broken_image_outlined)), imageUrl: reservation.productImageUrl!, fit: BoxFit.cover)
                    : Container(color: AppColors.neutralBg, child: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(reservation.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      StatusBadge(label: reservation.status.label, tone: reservationStatusTone(reservation.status)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    showConsumerName ? reservation.consumerName : reservation.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${reservation.quantity} ${reservation.fulfillmentType.label} · ${AppFormatters.dateTime(reservation.scheduledFor)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
