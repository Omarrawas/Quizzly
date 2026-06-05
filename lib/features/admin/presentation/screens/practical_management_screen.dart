import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';
import 'package:quizzly/features/subject/presentation/screens/practical_lesson_detail_screen.dart';
import 'package:quizzly/features/admin/presentation/widgets/unified_lesson_editor.dart';

class PracticalManagementScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String sectionId;
  final String sectionName;

  const PracticalManagementScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.sectionId,
    required this.sectionName,
  });

  @override
  State<PracticalManagementScreen> createState() =>
      _PracticalManagementScreenState();
}

class _PracticalManagementScreenState extends State<PracticalManagementScreen> {
  Query get _query => FirebaseFirestore.instance
      .collection('topics')
      .where('subjectId', isEqualTo: widget.subjectId)
      // .where('sectionId', isEqualTo: widget.sectionId) // removed to match student screen
      .where('type', isEqualTo: 'practical');

  Future<void> _deleteLesson(String docId) async {
    await FirebaseFirestore.instance.collection('topics').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        title: Text(
          'إدارة الدروس العملية - ${widget.subjectName}',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'حدث خطأ في جلب البيانات. قد يكون السبب نقص في الفهرسة (Index).\nالخطأ: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: Colors.red),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = [...snapshot.data!.docs]
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime); // Descending
            });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد دروس مضافة\nاضغط + لإضافة أول درس',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(color: Colors.grey, height: 1.6),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? data['name'] ?? 'بدون عنوان';

              return _LessonAdminCard(
                docId: doc.id,
                data: data,
                title: title,
                isDark: isDark,
                onDelete: () => _confirmDelete(context, doc.id, title),
                onEdit: () => _openEditLessonSheet(context, doc.id, data),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddLessonSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'إضافة درس جديد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'حذف الدرس',
          style: GoogleFonts.cairo(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text('هل تريد حذف "$title"؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteLesson(id);
            },
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAddLessonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnifiedLessonEditorSheet(
        subjectId: widget.subjectId,
        sectionId: widget.sectionId,
        type: 'practical',
      ),
    );
  }

  void _openEditLessonSheet(BuildContext context, String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnifiedLessonEditorSheet(
        subjectId: widget.subjectId,
        sectionId: widget.sectionId,
        type: 'practical',
        docId: docId,
        initialData: data,
      ),
    );
  }
}

class _LessonAdminCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String title;
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _LessonAdminCard({
    required this.docId,
    required this.data,
    required this.title,
    required this.isDark,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final description = data['description'] as String? ?? '';
    final mediaType = data['mediaType'] as String? ?? 'none';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            // Allow admin to preview the lesson
            final item = PracticalItem.fromMap(docId, data);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PracticalLessonDetailScreen(item: item),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    mediaType == 'video'
                        ? Icons.play_circle_rounded
                        : mediaType == 'images'
                        ? Icons.photo_library_rounded
                        : Icons.text_snippet_rounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (data['isFree'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                'مجاني',
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
