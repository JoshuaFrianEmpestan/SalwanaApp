import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../constants/enums.dart';
import '../theme/app_colors.dart';
import 'status_badge.dart';

class AccountHeaderCard extends StatelessWidget {
  final AppUser user;
  final String? subtitle;
  final VoidCallback? onEditProfile;

  const AccountHeaderCard({super.key, required this.user, this.subtitle, this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primarySurface,
            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(user.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                    if (onEditProfile != null)
                      IconButton(
                        onPressed: onEditProfile,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit Profile',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(subtitle ?? user.email,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                StatusBadge(label: user.role.label, tone: BadgeTone.info),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
