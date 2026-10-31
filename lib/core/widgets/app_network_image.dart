import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reliable network image widget.
///
/// On web, `CachedNetworkImage` is prone to rendering black rectangles after
/// tab switches. Using `Image.network` on web delegates decoding to the
/// browser, which is far more robust. On native platforms we keep
/// `CachedNetworkImage` for disk caching.
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: AppColors.neutralBg,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stack) => Container(
          width: width,
          height: height,
          color: AppColors.neutralBg,
          child: const Icon(Icons.broken_image_outlined, color: AppColors.textDisabled),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: (ctx, url) => Container(color: AppColors.neutralBg),
      errorWidget: (ctx, url, err) => Container(
        color: AppColors.neutralBg,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.textDisabled),
      ),
    );
  }
}
