import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeTone { success, warning, error, info, pending, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;

  const StatusBadge({super.key, required this.label, required this.tone});

  (Color, Color) get _colors => switch (tone) {
        BadgeTone.success => (AppColors.successBg, AppColors.success),
        BadgeTone.warning => (AppColors.warningBg, AppColors.warning),
        BadgeTone.error => (AppColors.errorBg, AppColors.error),
        BadgeTone.info => (AppColors.infoBg, AppColors.info),
        BadgeTone.pending => (AppColors.pendingBg, AppColors.pending),
        BadgeTone.neutral => (AppColors.neutralBg, AppColors.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
