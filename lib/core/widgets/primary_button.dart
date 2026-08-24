import 'package:flutter/material.dart';

/// Standard submit button. Automatically disables itself and shows a
/// spinner while [loading] is true, so the same widget prevents
/// double-submits across every form in the app.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outlined;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Text(label),
            ],
          );

    final effectiveOnPressed = loading ? null : onPressed;

    if (outlined) {
      return OutlinedButton(onPressed: effectiveOnPressed, child: child);
    }
    return ElevatedButton(onPressed: effectiveOnPressed, child: child);
  }
}
