import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';

class MicroscopicAtlasScreen extends StatefulWidget {
  final PracticalItem item;

  const MicroscopicAtlasScreen({super.key, required this.item});

  @override
  State<MicroscopicAtlasScreen> createState() => _MicroscopicAtlasScreenState();
}

class _MicroscopicAtlasScreenState extends State<MicroscopicAtlasScreen>
    with SingleTickerProviderStateMixin {
  bool _showLabels = true;
  late AnimationController _labelAnimController;
  late Animation<double> _labelFadeAnim;

  @override
  void initState() {
    super.initState();
    _labelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _labelFadeAnim = CurvedAnimation(
      parent: _labelAnimController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _labelAnimController.dispose();
    super.dispose();
  }

  void _toggleLabels() {
    setState(() => _showLabels = !_showLabels);
    if (_showLabels) {
      _labelAnimController.forward(from: 0);
    } else {
      _labelAnimController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        leading: Builder(
          builder: (context) {
            final isRtl = Directionality.of(context) == TextDirection.rtl;
            return IconButton(
              icon: Icon(
                isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            );
          },
        ),
        title: Text(
          widget.item.title,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Labels toggle button with animated state
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _showLabels
                  ? const Color(0xFF0D9488).withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: GestureDetector(
              onTap: _toggleLabels,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showLabels ? Icons.label_rounded : Icons.label_off_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showLabels ? 'إخفاء المسميات' : 'إظهار المسميات',
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Image Viewer with Labels ──────────────────────────
          Expanded(
            child: InteractiveViewer(
              maxScale: 6.0,
              minScale: 0.8,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Main Image
                        SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: Image.network(
                            widget.item.imageUrl ?? '',
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                              null
                                          ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                          : null,
                                      color: const Color(0xFF0D9488),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'جاري تحميل الصورة...',
                                      style: GoogleFonts.cairo(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
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
                                        style: GoogleFonts.cairo(
                                          color: Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                        ),
                        // Labels Layer — positioned relative to container
                        if (widget.item.labels != null)
                          FadeTransition(
                            opacity: _labelFadeAnim,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: Stack(
                                children: widget.item.labels!.map((label) {
                                  return Positioned(
                                    left: constraints.maxWidth * label.x,
                                    top: constraints.maxHeight * label.y,
                                    child: _buildLabelChip(label),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Info Panel ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A26) : Colors.white,
              border: const Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.biotech_rounded,
                      color: Color(0xFF0891B2),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item.title,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Label count badge
                    if (widget.item.labels != null &&
                        widget.item.labels!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0891B2,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.item.labels!.length} مسمى',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: const Color(0xFF0891B2),
                          ),
                        ),
                      ),
                  ],
                ),
                if (widget.item.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.item.description,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                // Self-test hint
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tips_and_updates_rounded,
                        color: Color(0xFF0D9488),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _showLabels
                              ? 'اضغط زر "إخفاء المسميات" لاختبار معرفتك بالأجزاء'
                              : 'هل تعرف جميع الأجزاء؟ اضغط "إظهار المسميات" للتحقق',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelChip(MicroscopicLabel label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF0D9488), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF0D9488),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label.label,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
