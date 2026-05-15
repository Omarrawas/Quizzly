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
  /// When true, always shows the student lesson view (never redirects to admin management)
  final bool isViewOnly;

  const PracticalSectionScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.isViewOnly = false,
  });

  @override
  State<PracticalSectionScreen> createState() => _PracticalSectionScreenState();
}

class _PracticalSectionScreenState extends State<PracticalSectionScreen> {
  String? _sectionId;
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
        _sectionId = sId;
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

    if (_sectionId == null && false) { // Skip this check, we can show lessons even without a section document
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('الدفتر العملي - ${widget.subjectName}', style: GoogleFonts.cairo()),
        ),
        body: _buildEmptyState(isDark),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الدفتر العملي - ${widget.subjectName}',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('topics')
            .where('subjectId', isEqualTo: widget.subjectId)
            // .where('sectionId', isEqualTo: _sectionId) // removed to fetch ALL practical lessons for this subject
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
