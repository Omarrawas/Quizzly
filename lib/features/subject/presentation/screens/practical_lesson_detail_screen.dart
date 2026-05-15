import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';
import 'package:quizzly/core/widgets/video/video_download_button.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';

class PracticalLessonDetailScreen extends StatefulWidget {
  final PracticalItem item;

  const PracticalLessonDetailScreen({super.key, required this.item});

  @override
  State<PracticalLessonDetailScreen> createState() => _PracticalLessonDetailScreenState();
}

class _PracticalLessonDetailScreenState extends State<PracticalLessonDetailScreen> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Content Section (Title First) ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.cairo(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            'آخر تحديث: ${item.lastUpdated}',
                            style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Media Section ──────────────────────────────
                const SizedBox(height: 16),
                if (item.mediaType == 'video' && item.videoUrl != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OfflineAwareVideoWidget(
                      lessonId: item.id,
                      videoUrl: item.videoUrl!,
                      title: item.title,
                      height: 220,
                    ),
                  ),
                
                if (item.mediaType == 'images' && item.imageUrls.isNotEmpty)
                  _buildImageCarousel(item.imageUrls, isDark),

                // ── Explanation Section ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 40),
                      Text(
                        'الشرح والتفاصيل',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TexViewWidget(
                        text: item.description,
                        fontSize: 15,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      
                      // Support legacy content if present
                      if (item.content != null && item.content!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        TexViewWidget(
                          text: item.content!,
                          fontSize: 15,
                          color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, 
          color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        'درس عملي',
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildImageCarousel(List<String> urls, bool isDark) {
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            itemCount: urls.length,
            onPageChanged: (index) => setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    urls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (urls.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: urls.asMap().entries.map((entry) {
              return Container(
                width: _currentImageIndex == entry.key ? 18.0 : 6.0,
                height: 6.0,
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _currentImageIndex == entry.key
                      ? AppColors.primaryBlue
                      : (isDark ? Colors.white24 : Colors.grey[300]),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
