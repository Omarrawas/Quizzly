import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';
import 'package:quizzly/features/subject/presentation/screens/practical_lesson_detail_screen.dart';

class PracticalSectionScreen extends StatelessWidget {
  final String subjectId;
  final String subjectName;

  const PracticalSectionScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  Future<String?> _fetchPracticalSectionId() async {
    final snap = await FirebaseFirestore.instance
        .collection('sections')
        .where('parentId', isEqualTo: subjectId)
        .get();
    for (final doc in snap.docs) {
      final name = (doc.data()['name'] ?? '') as String;
      if (name.contains('عملي')) return doc.id;
    }
    return null;
  }

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
          'الدفتر العملي - $subjectName',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<String?>(
        future: _fetchPracticalSectionId(),
        builder: (context, sectionSnap) {
          if (sectionSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sectionId = sectionSnap.data;
          if (sectionId == null) return _buildEmptyState(isDark);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('topics')
                .where('subjectId', isEqualTo: subjectId)
                .where('sectionId', isEqualTo: sectionId)
                .where('type', isEqualTo: 'practical')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, lessonSnap) {
              if (lessonSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = lessonSnap.data?.docs ?? [];
              if (docs.isEmpty) return _buildEmptyState(isDark);

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final item = PracticalItem.fromFirestore(docs[index]);
                  return _buildLessonCard(context, item, isDark);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text('لا توجد دروس عملية مضافة حالياً', style: GoogleFonts.cairo(color: isDark ? Colors.white38 : AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildLessonCard(BuildContext context, PracticalItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PracticalLessonDetailScreen(item: item))),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.mediaType != 'none') _buildMediaPreview(item, isDark),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 13, color: isDark ? Colors.white60 : AppColors.textSecondary, height: 1.5)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(item.lastUpdated, style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey[400])),
                        const Spacer(),
                        Text('عرض الدرس', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488))),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF0D9488)),
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
      decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[100], borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.mediaType == 'images' && item.imageUrls.isNotEmpty)
            Image.network(item.imageUrls.first, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image_rounded, color: Colors.grey)),
          if (item.mediaType == 'video')
            Container(color: Colors.black87, child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 50)),
        ],
      ),
    );
  }
}
