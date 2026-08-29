import 'package:flutter/widgets.dart';

/// Wraps a form's scrollable content so it stays full-width on phones but
/// caps at a readable line length and centers on tablet/desktop, instead
/// of stretching a single-column form edge-to-edge on a wide screen.
class ResponsiveFormBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveFormBody({super.key, required this.child, this.maxWidth = 560});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
