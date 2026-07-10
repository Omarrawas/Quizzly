import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';
import 'package:quizzly/features/subject/presentation/screens/muzakara_detail_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/microscopic_atlas_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/experiment_guide_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/oral_interview_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/practical_lesson_detail_screen.dart';

class PracticalCategoryListScreen extends StatelessWidget {
  final String subjectId;
  final String? sectionId; // optional – when present, scopes query to exact section
  final PracticalCategory category;
  final String title;

  const PracticalCategoryListScreen({
    super.key,
    required this.subjectId,
    this.sectionId,
    required this.category,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C14) : const Color(0xFFE5E2DA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131A26) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
        ),
        leading: Builder(
          builder: (context) {
            final isRtl = Directionality.of(context) == TextDirection.rtl;
            return IconButton(
              icon: Icon(
                isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : AppColors.textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            );
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ في تحميل البيانات', style: GoogleFonts.cairo()));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final item = PracticalItem.fromFirestore(docs[index]);
              return _buildItemCard(context, item, isDark);
            },
          );
        },
      ),
    );
  }

  /// Builds the correct Firestore query.
  /// If [sectionId] is provided, scopes to that exact section (matches admin save).
  /// Otherwise falls back to subject-wide search for backward compatibility.
  Query _buildQuery() {
    Query q = FirebaseFirestore.instance
        .collection('topics')
        .where('subjectId', isEqualTo: subjectId)
        .where('type', isEqualTo: 'practical')
        .where('subType', isEqualTo: category.name);

    if (sectionId != null) {
      q = q.where('sectionId', isEqualTo: sectionId);
    }

    return q.orderBy('createdAt', descending: true);
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا يوجد محتوى في هذا القسم حالياً',
            style: GoogleFonts.cairo(color: isDark ? Colors.white38 : AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, PracticalItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A26) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => _navigateToDetail(context, item),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Media Preview ──────────────────────────────────
              if (item.mediaType != 'none')
                _buildMediaPreview(item, isDark),

              // ── Text Content ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildCategoryBadge(item.category),
                        const Spacer(),
                        if (item.isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'جديد',
                              style: GoogleFonts.cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[700],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.title,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          item.lastUpdated,
                          style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey[400]),
                        ),
                        const Spacer(),
                        Text(
                          'عرض الدرس',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primaryBlue),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(PracticalItem item, bool isDark) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.mediaType == 'images' && item.imageUrls.isNotEmpty)
            Image.network(
              item.imageUrls.first,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
            ),
          if (item.mediaType == 'video')
            Container(
              color: Colors.black87,
              child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 50),
            ),
          // Gradient overlay for better text contrast if needed
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.1), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(PracticalCategory category) {
    String label;
    IconData icon;
    Color color;

    switch (category) {
      case PracticalCategory.summary: label = 'مذاكرة'; icon = Icons.description_rounded; color = const Color(0xFF0D9488); break;
      case PracticalCategory.drawing: label = 'أطلس'; icon = Icons.biotech_rounded; color = const Color(0xFF0891B2); break;
      case PracticalCategory.experiment: label = 'تجربة'; icon = Icons.science_rounded; color = const Color(0xFF4F46E5); break;
      case PracticalCategory.interview: label = 'مقابلة'; icon = Icons.record_voice_over_rounded; color = const Color(0xFF7C3AED); break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context, PracticalItem item) {
    Widget screen;

    // Favor the new Lesson format if media or specific lesson fields are present
    if (item.mediaType != 'none' || item.videoUrl != null || item.imageUrls.isNotEmpty) {
      screen = PracticalLessonDetailScreen(item: item);
    } else {
      // Fallback to specialized screens for legacy data
      switch (item.category) {
        case PracticalCategory.summary:
          screen = MuzakaraDetailScreen(item: item);
          break;
        case PracticalCategory.drawing:
          screen = MicroscopicAtlasScreen(item: item);
          break;
        case PracticalCategory.experiment:
          screen = ExperimentGuideScreen(item: item);
          break;
        case PracticalCategory.interview:
          screen = OralInterviewScreen(item: item);
          break;
      }
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }
}
