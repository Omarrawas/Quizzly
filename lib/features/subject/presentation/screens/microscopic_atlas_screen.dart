import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';

class MicroscopicAtlasScreen extends StatefulWidget {
  final PracticalItem item;

  const MicroscopicAtlasScreen({super.key, required this.item});

  @override
  State<MicroscopicAtlasScreen> createState() => _MicroscopicAtlasScreenState();
}

class _MicroscopicAtlasScreenState extends State<MicroscopicAtlasScreen> {
  bool _showLabels = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.item.title,
          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_showLabels ? Icons.label_rounded : Icons.label_outline_rounded, color: Colors.white),
            onPressed: () => setState(() => _showLabels = !_showLabels),
            tooltip: 'إظهار/إخفاء المسميات',
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              maxScale: 5.0,
              child: Stack(
                children: [
                  // Drawing Image
                  Hero(
                    tag: widget.item.id,
                    child: Image.network(
                      widget.item.imageUrl ?? '',
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[900],
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48)),
                      ),
                    ),
                  ),
                  // Labels Layer
                  if (_showLabels && widget.item.labels != null)
                    ...widget.item.labels!.map((label) => _buildLabel(label)),
                ],
              ),
            ),
          ),
          _buildInfoPanel(isDark),
        ],
      ),
    );
  }

  Widget _buildLabel(MicroscopicLabel label) {
    return Positioned(
      left: MediaQuery.of(context).size.width * label.x,
      top: MediaQuery.of(context).size.height * label.y,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF0D9488), width: 1),
        ),
        child: Text(
          label.label,
          style: GoogleFonts.cairo(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(bool isDark) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF0D9488), size: 20),
                const SizedBox(width: 8),
                Text(
                  'وصف الرسمة',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.description,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
