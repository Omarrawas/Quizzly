import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class ZoomableImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? height;
  final double? width;
  final BorderRadius borderRadius;

  const ZoomableImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  void _showZoomedImage(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // InteractiveViewer for pinch-to-zoom and pan
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6E56FF), // Primary dark fintech color
                      ),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white24,
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'تعذّر تحميل الصورة',
                            style: GoogleFonts.tajawal(
                              color: Colors.white38,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Close button, aligned properly for RTL (top-left) or LTR (top-right)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: Directionality.of(context) == TextDirection.rtl ? null : 20,
              left: Directionality.of(context) == TextDirection.rtl ? 20 : null,
              child: SafeArea(
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
            // Floating instruction overlay at the bottom
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'استخدم إصبعين للتكبير والتمرير',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showZoomedImage(context),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              height: height,
              width: width,
              fit: fit,
              placeholder: (context, url) => Container(
                height: height ?? 150,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF222329) 
                    : const Color(0xFFF1F5F9),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6E56FF),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
            // Subtle zoom overlay hint on the image itself
            Positioned(
              bottom: 8,
              left: Directionality.of(context) == TextDirection.rtl ? 8 : null,
              right: Directionality.of(context) == TextDirection.rtl ? null : 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.zoom_in_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
