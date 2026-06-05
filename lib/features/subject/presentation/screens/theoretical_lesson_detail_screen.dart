import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_book_mode_screen.dart';
import 'package:quizzly/core/widgets/video/video_download_button.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/quiz/presentation/widgets/interactive_explanation.dart';
import 'package:url_launcher/url_launcher.dart';

class TheoreticalLessonDetailScreen extends StatefulWidget {
  final String lessonId;
  final String lessonName;
  final String subjectId;
  final String subjectName;
  final String sectionId;
  final Map<String, dynamic> data;

  const TheoreticalLessonDetailScreen({
    super.key,
    required this.lessonId,
    required this.lessonName,
    required this.subjectId,
    required this.subjectName,
    required this.sectionId,
    required this.data,
  });

  @override
  State<TheoreticalLessonDetailScreen> createState() => _TheoreticalLessonDetailScreenState();
}

class _TheoreticalLessonDetailScreenState extends State<TheoreticalLessonDetailScreen> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.data;
    final description = data['description'] ?? 'لا يوجد شرح متاح حالياً لهذا الدرس.';
    final videoUrl = data['videoUrl'] as String?;
    final imageUrls = List<String>.from(data['imageUrls'] ?? []);
    final mediaType = data['mediaType'] ?? 'text';
    final lastUpdated = data['lastUpdated'] ?? 'غير محدد';
    final attachments = data['attachments'] != null ? List<Map<String, dynamic>>.from(data['attachments']) : [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Section ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lessonName,
                        style: GoogleFonts.cairo(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.update_rounded, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            'آخر تحديث: $lastUpdated',
                            style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Media Section ──────────────────────────────────
                const SizedBox(height: 20),
                if (mediaType == 'video' && videoUrl != null && videoUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: OfflineAwareVideoWidget(
                      lessonId: widget.lessonId,
                      videoUrl: videoUrl,
                      title: widget.lessonName,
                      height: 220,
                    ),
                  ),
                
                if (mediaType == 'images' && imageUrls.isNotEmpty)
                  _buildImageCarousel(imageUrls, isDark),

                // ── Explanation Section ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 40),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.description_rounded, color: Colors.blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'الشرح والتفاصيل',
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TexViewWidget(
                        text: description,
                        fontSize: 16,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),

                      // -- NEW: Attachments Section --
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.attach_file_rounded, color: Color(0xFF0D9488), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'المرفقات الإضافية',
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...attachments.map((att) => _buildAttachmentTile(att, isDark)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildTestButton(isDark),
    );
  }

  Widget _buildAttachmentTile(Map<String, dynamic> att, bool isDark) {
    final type = att['type'] as String? ?? 'other';
    final url = att['url'] as String? ?? '';
    final title = att['title'] as String? ?? 'ملف مرفق';

    Widget viewer;
    if (type == 'pdf') {
      viewer = PdfExplanationViewer(pdfUrl: url);
    } else if (type == 'audio') {
      viewer = AudioExplanationPlayer(audioUrl: url);
    } else if (type == 'video') {
      viewer = QuickExplanationVideo(videoUrl: url);
    } else {
      viewer = InkWell(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file_rounded, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
              const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.blue),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (type != 'pdf' && type != 'audio')
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 4),
              child: Text(title, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          viewer,
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      leading: IconButton(
        icon: Icon(
          isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded, 
          color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        'المحتوى النظري',
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
          height: 300,
          child: PageView.builder(
            itemCount: urls.length,
            onPageChanged: (index) => setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: urls.asMap().entries.map((entry) {
                return Container(
                  width: _currentImageIndex == entry.key ? 20.0 : 6.0,
                  height: 6.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: _currentImageIndex == entry.key
                        ? AppColors.primaryBlue
                        : (isDark ? Colors.white24 : Colors.grey[300]),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTestButton(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          shadowColor: AppColors.primaryBlue.withValues(alpha: 0.5),
        ),
        onPressed: () => _openLessonInBookMode(widget.lessonId, widget.lessonName),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz_rounded),
            const SizedBox(width: 12),
            Text(
              'اختبر نفسك في هذا الدرس',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLessonInBookMode(String lessonId, String lessonName) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection(DatabaseService.colQuestions)
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('topicIds', arrayContains: lessonId)
          .get();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loader
 
      final questions = snap.docs.map((doc) => QuizQuestion.fromFirestore(doc)).toList();
      
      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا توجد أسئلة مضافة لهذا الدرس حالياً', style: GoogleFonts.cairo()),
            behavior: SnackBarBehavior.floating,
          )
        );
        return;
      }

      final config = ExamConfig(
        id: 'lesson_$lessonId',
        title: lessonName,
        type: ExamType.bank,
        durationSeconds: 0,
        totalQuestions: questions.length,
        passingScore: 50,
        subjectId: widget.subjectId,
        sectionId: widget.sectionId,
        staticQuestionIds: questions.map((q) => q.id ?? '').toList(),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExamBookModeScreen(
            config: config,
            questions: questions,
            isSubExam: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }
}
