import 'package:flutter/widgets.dart';

/// Shared width breakpoints so every screen agrees on what counts as
/// mobile/tablet/desktop, rather than each widget picking its own cutoff.
class Breakpoints {
  Breakpoints._();

  static const double tablet = 600;
  static const double desktop = 1024;

  static bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= tablet;
  static bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= desktop;

  /// Grid column count that grows with available width, used by every
  /// product/browsing grid instead of a hardcoded crossAxisCount.
  static int gridColumns(double width) {
    if (width >= desktop) return 4;
    if (width >= tablet) return 3;
    return 2;
  }
}
