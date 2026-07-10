import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';
import 'package:quizzly/core/widgets/video/video_download_button.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/quiz/presentation/widgets/interactive_explanation.dart';
import 'package:url_launcher/url_launcher.dart';

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
      backgroundColor: isDark ? const Color(0xFF080C14) : const Color(0xFFE5E2DA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context, isDark, item),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Media Section ──────────────────────────────────
                if (item.mediaType == 'video' && item.videoUrl != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: OfflineAwareVideoWidget(
                          lessonId: item.id,
                          videoUrl: item.videoUrl!,
                          title: item.title,
                          height: 240,
                        ),
                      ),
                    ),
                  ),
                
                if (item.mediaType == 'images' && item.imageUrls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildImageCarousel(item.imageUrls, isDark),
                  ),

                // ── Content Section ──────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildMediaBadge(item, isDark),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.history_rounded, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  'تحديث: ${item.lastUpdated}',
                                  style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        item.title,
                        style: GoogleFonts.cairo(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      _buildSectionTitle('الشرح والتفاصيل', Icons.description_rounded, isDark),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131A26).withValues(alpha: 0.5) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[100]!),
                        ),
                        child: TexViewWidget(
                          text: item.description,
                          fontSize: 15,
                          color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // -- Attachments --
                      // Need to access raw data for attachments since they aren't in the PracticalItem model yet
                      // -- Attachments Section --
                      if (item.attachments.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildSectionTitle('المرفقات الإضافية', Icons.attach_file_rounded, isDark),
                        const SizedBox(height: 16),
                        ...item.attachments.map((att) => _buildAttachmentTile(att, isDark)),
                      ],
                      // Detailed Sections (Legacy Support)
                      if (item.microscopicLabels.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildSectionTitle('التحليل المجهري', Icons.biotech_rounded, isDark),
                        const SizedBox(height: 12),
                        ...item.microscopicLabels.map((l) => _buildDetailItem(l.label, isDark)),
                      ],

                      if (item.experiments.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildSectionTitle('التجارب العلمية', Icons.science_rounded, isDark),
                        const SizedBox(height: 12),
                        ...item.experiments.map((e) => _buildDetailItem(e, isDark)),
                      ],

                      if (item.interviews.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildSectionTitle('المقابلات والمناقشات', Icons.forum_rounded, isDark),
                        const SizedBox(height: 12),
                        ...item.interviews.map((i) => _buildDetailItem('${i.question}\n${i.answer}', isDark)),
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

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0D9488)),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String text, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : (Colors.grey[50] ?? Colors.grey).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF0D9488),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TexViewWidget(
              text: text,
              fontSize: 14,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
          if (type != 'pdf' && type != 'audio') // PDF and Audio have titles inside
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 4),
              child: Text(title, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          viewer,
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isDark, PracticalItem item) {
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF131A26) : Colors.white,
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
      centerTitle: true,
      title: Text(
        'عرض الدرس',
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildMediaBadge(PracticalItem item, bool isDark) {
    IconData icon;
    String label;
    Color color;

    switch (item.mediaType) {
      case 'video':
        icon = Icons.videocam_rounded;
        label = 'فيديو';
        color = Colors.red;
        break;
      case 'images':
        icon = Icons.collections_rounded;
        label = 'صور';
        color = Colors.blue;
        break;
      default:
        icon = Icons.article_rounded;
        label = 'نصي';
        color = Colors.teal;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
