import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/presentation/screens/theoretical_section_management_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/theoretical_lesson_detail_screen.dart';
import 'package:quizzly/features/admin/presentation/widgets/unified_lesson_editor.dart';

class LessonManagementScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String sectionId;
  final String sectionName;
  final String chapterId;
  final String chapterName;
  final List<String> breadcrumbs;

  const LessonManagementScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.sectionId,
    required this.sectionName,
    required this.chapterId,
    required this.chapterName,
    required this.breadcrumbs,
  });

  @override
  State<LessonManagementScreen> createState() => _LessonManagementScreenState();
}

class _LessonManagementScreenState extends State<LessonManagementScreen> {
  final DatabaseService _dbService = DatabaseService();

  num _readOrder(Map<String, dynamic> data) {
    final value = data['order'];
    return value is num ? value : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chapterName,
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'دروس الفصل',
              style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getTopics(
          widget.subjectId,
          sectionId: widget.sectionId,
          parentId: widget.chapterId,
          type: 'lesson',
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...snapshot.data!.docs]
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aOrder = _readOrder(aData);
              final bOrder = _readOrder(bData);
              if (aOrder != bOrder) return aOrder.compareTo(bOrder);
              final aTime = (aData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bTime = (bData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return aTime.compareTo(bTime);
            });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد دروس في هذا الفصل حالياً.',
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: docs.length,
            onReorder: (oldIndex, newIndex) => _handleLessonReorder(docs, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final id = doc.id;
              final name = data['name'] ?? '';

              return Container(
                key: ValueKey(id),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
                ),
                child: ListTile(
                  onTap: () => _goToLessonQuestions(id, name),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: isDark ? Colors.white24 : Colors.grey[300],
                    ),
                  ),
                  title: TexViewWidget(
                    text: name,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_red_eye_rounded, color: AppColors.primaryBlue, size: 20),
                        onPressed: () => _previewLesson(id, name, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.video_collection_rounded, color: Colors.orange, size: 20),
                        onPressed: () => _showEditLessonContentDialog(id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 20),
                        onPressed: () => _showEditTopicDialog(id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                        onPressed: () => _confirmDelete(id, name),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLessonSheet(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('إضافة درس جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  Future<void> _handleLessonReorder(List<QueryDocumentSnapshot> docs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final List<String> ids = docs.map((d) => d.id).toList();
    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);
    try {
      await _dbService.updateOrder(DatabaseService.colTopics, ids);
    } catch (_) {}
  }

  void _goToLessonQuestions(String lessonId, String lessonName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TheoreticalSectionManagementScreen(
          sectionId: widget.sectionId,
          sectionName: widget.sectionName,
          subjectId: widget.subjectId,
          breadcrumbs: [...widget.breadcrumbs, lessonName],
          lessonId: lessonId,
          lessonName: lessonName,
        ),
      ),
    );
  }

  void _previewLesson(String lessonId, String lessonName, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TheoreticalLessonDetailScreen(
          lessonId: lessonId,
          lessonName: lessonName,
          subjectId: widget.subjectId,
          subjectName: widget.subjectName,
          sectionId: widget.sectionId,
          data: data,
        ),
      ),
    );
  }

  void _showAddLessonSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnifiedLessonEditorSheet(
        subjectId: widget.subjectId,
        sectionId: widget.sectionId,
        type: 'lesson',
        parentId: widget.chapterId,
      ),
    );
  }

  void _showEditLessonContentDialog(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnifiedLessonEditorSheet(
        subjectId: widget.subjectId,
        sectionId: widget.sectionId,
        type: 'lesson',
        parentId: widget.chapterId,
        docId: id,
        initialData: data,
      ),
    );
  }

  void _showEditTopicDialog(String id, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل اسم الدرس', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: 'الاسم', labelStyle: GoogleFonts.cairo()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _dbService.updateDoc(DatabaseService.colTopics, id, {'name': nameController.text.trim()});
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف الدرس', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من حذف الدرس "$name"؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await _dbService.deleteTopicCascade(id, 'lesson');
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
