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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _navigateToDetail(context, item),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildIcon(item.category),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white24 : Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(PracticalCategory category) {
    IconData icon;
    Color color;

    switch (category) {
      case PracticalCategory.summary:
        icon = Icons.description_rounded;
        color = const Color(0xFF0D9488);
        break;
      case PracticalCategory.drawing:
        icon = Icons.biotech_rounded;
        color = const Color(0xFF0891B2);
        break;
      case PracticalCategory.experiment:
        icon = Icons.science_rounded;
        color = const Color(0xFF4F46E5);
        break;
      case PracticalCategory.interview:
        icon = Icons.record_voice_over_rounded;
        color = const Color(0xFF7C3AED);
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 24),
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
