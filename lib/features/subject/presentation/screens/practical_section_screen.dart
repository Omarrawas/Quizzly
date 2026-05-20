import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/admin/presentation/screens/practical_management_screen.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/subject/presentation/screens/practical_lesson_detail_screen.dart';

class PracticalSectionScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final bool isViewOnly;
  final bool isFree;

  const PracticalSectionScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.isViewOnly = false,
    this.isFree = false,
  });

  @override
  State<PracticalSectionScreen> createState() => _PracticalSectionScreenState();
}

class _PracticalSectionScreenState extends State<PracticalSectionScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthService>();
    final sId = await _fetchPracticalSectionId();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // If admin AND not in view-only mode, redirect to management immediately
      if (auth.isAdmin && !widget.isViewOnly) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PracticalManagementScreen(
              subjectId: widget.subjectId,
              subjectName: widget.subjectName,
              sectionId: sId ?? 'practical', // Fallback to 'practical' if no section found
              sectionName: 'القسم العملي',
            ),
          ),
        );
      }
    }
  }

  Future<String?> _fetchPracticalSectionId() async {
    final snap = await FirebaseFirestore.instance
        .collection('sections')
        .where('parentId', isEqualTo: widget.subjectId)
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }



    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الدروس العملية - ${widget.subjectName}',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontSize: 16,
          ),
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
        stream: FirebaseFirestore.instance
            .collection('topics')
            .where('subjectId', isEqualTo: widget.subjectId)
            .where('type', isEqualTo: 'practical')
            .snapshots(),
        builder: (context, lessonSnap) {
          if (lessonSnap.hasError) {
            return _buildErrorState(isDark, lessonSnap.error.toString());
          }
          
          if (lessonSnap.connectionState == ConnectionState.waiting) {
            return _buildLoadingSkeleton(isDark);
          }

          final rawDocs = lessonSnap.data?.docs ?? [];
          if (rawDocs.isEmpty) return _buildEmptyState(isDark);

          final docs = rawDocs.toList()..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final item = PracticalItem.fromFirestore(docs[index]);
              return _buildLessonCard(context, item, isDark, index);
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(height: 14, width: 200, color: isDark ? Colors.white10 : Colors.grey[200]),
                  const SizedBox(height: 8),
                  Container(height: 10, width: double.infinity, color: isDark ? Colors.white10 : Colors.grey[200]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'عذراً، حدث خطأ أثناء تحميل الدروس',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'تأكد من وجود فهرس (Index) في Firestore لهذه الترتيبات.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.science_rounded, 
                size: 60, 
                color: isDark ? Colors.white24 : Colors.grey[300],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'لا توجد دروس عملية مضافة حالياً',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'سيظهر هنا جميع الدروس العملية، الرسوم التوضيحية، ومقاطع الفيديو عند إضافتها من قبل المشرف.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text(
              'محتوى مقفل',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'هذا الدرس يتطلب الاشتراك في المادة. يرجى تفعيل المادة بالكود لفتح جميع الدروس والاختبارات العملية.',
          style: GoogleFonts.cairo(
            color: isDark ? Colors.white70 : AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to subject hub to activate
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('الاشتراك الآن', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(BuildContext context, PracticalItem item, bool isDark, int index) {
    final isLocked = widget.isFree && !item.isFree;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLocked ? (isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber.shade200) : (isDark ? Colors.white10 : Colors.grey[200]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), 
            blurRadius: 15, 
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            if (isLocked) {
              _showSubscriptionDialog();
            } else {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => PracticalLessonDetailScreen(item: item),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Opacity(
                opacity: isLocked ? 0.6 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.mediaType != 'none') 
                      _buildMediaPreview(item, isDark)
                    else
                      _buildDefaultPreview(item, isDark),
                    
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTypeBadge(item.mediaType, isDark),
                                    const SizedBox(height: 12),
                                    Text(
                                      item.title,
                                      style: GoogleFonts.cairo(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (!isLocked)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: AppColors.primaryBlue,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 12),
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
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'تحديث: ${item.lastUpdated}',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const Spacer(),
                              if (!isLocked)
                                Text(
                                  'عرض الدرس',
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isLocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 32),
                      ),
                    ),
                  ),
                ),
              if (item.isFree && widget.isFree)
                Positioned.directional(
                  textDirection: TextDirection.rtl,
                  top: 16,
                  end: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'مجاني',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type, bool isDark) {
    IconData icon;
    String label;
    Color color;

    switch (type) {
      case 'video':
        icon = Icons.play_circle_fill_rounded;
        label = 'فيديو تعليمي';
        color = const Color(0xFFEF4444);
        break;
      case 'images':
        icon = Icons.photo_library_rounded;
        label = 'معرض صور';
        color = const Color(0xFF3B82F6);
        break;
      default:
        icon = Icons.text_snippet_rounded;
        label = 'درس نصي';
        color = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultPreview(PracticalItem item, bool isDark) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0D9488),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
