import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// App-wide offline indicator (§7 offline support). Reads/writes still work
/// while offline — Firestore serves cached data and queues writes — this
/// just makes that state visible instead of silently stale.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted && offline != _offline) setState(() => _offline = offline);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _offline
              ? const Material(
                  color: AppColors.warning,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "You're offline — showing cached data. Changes will sync once you're back online.",
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
