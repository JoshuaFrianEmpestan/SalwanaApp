import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Placeholder for a module not yet built out. Used only for screens still
/// pending implementation — never for a screen that should already be
/// functional. Each carries the module name so it's obvious what's next.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String moduleNote;
  final IconData icon;

  const ComingSoonScreen({super.key, required this.title, required this.moduleNote, this.icon = Icons.construction_rounded});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: AppColors.neutralBg, shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Text(
                'This screen is under construction',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                moduleNote,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
