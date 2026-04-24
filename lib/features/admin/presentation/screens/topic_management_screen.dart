import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/presentation/screens/theoretical_section_management_screen.dart';

class TopicManagementScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final List<String> breadcrumbs;

  final String sectionId;
  final String sectionName;

  const TopicManagementScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.breadcrumbs,
    required this.sectionId,
    required this.sectionName,
  });

  @override
  State<TopicManagementScreen> createState() => _TopicManagementScreenState();
}

class _TopicManagementScreenState extends State<TopicManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  String? _selectedChapterId;
  String? _selectedChapterName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('تصنيف المادة - ${widget.subjectName}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Row(
        children: [
          // Right Column: Chapters
          Expanded(
            flex: 2,
            child: _buildChaptersColumn(isDark),
          ),
          // Divider
          VerticalDivider(width: 1, color: isDark ? Colors.white10 : Colors.grey[300]),
          // Left Column: Lessons
          Expanded(
            flex: 3,
            child: _buildLessonsColumn(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersColumn(bool isDark) {
    return Column(
      children: [
        _buildColumnHeader('الفصول', Icons.folder_rounded, isDark, tooltip: 'إضافة فصل جديد', onAdd: () => _showAddTopicDialog(context, null, 'chapter')),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _dbService.getTopics(widget.subjectId, parentId: null, type: 'chapter'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return _emptyState('لا توجد فصول', isDark);

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;
                  final name = data['name'] ?? '';
                  final isSelected = _selectedChapterId == id;

                  return _buildListTile(
                    id: id,
                    title: name,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () => setState(() {
                      _selectedChapterId = id;
                      _selectedChapterName = name;
                    }),
                    onEdit: () => _showEditTopicDialog(id, data, 'فصل'),
                    onDelete: () => _confirmDelete(id, name),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLessonsColumn(bool isDark) {
    if (_selectedChapterId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_forward_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('اختر فصلاً لعرض دروسه', style: GoogleFonts.cairo(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildColumnHeader('دروس: $_selectedChapterName', Icons.menu_book_rounded, isDark, 
            tooltip: 'إضافة درس لهذا الفصل',
            onAdd: () => _showAddTopicDialog(context, _selectedChapterId, 'lesson')),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _dbService.getTopics(widget.subjectId, parentId: _selectedChapterId, type: 'lesson'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return _emptyState('لا توجد دروس في هذا الفصل', isDark);

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;
                  final name = data['name'] ?? '';

                  return _buildListTile(
                    id: id,
                    title: name,
                    isSelected: false,
                    isDark: isDark,
                    showArrow: true,
                    onTap: () => _goToLessonQuestions(id, name),
                    onEdit: () => _showEditTopicDialog(id, data, 'درس'),
                    onDelete: () => _confirmDelete(id, name),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeader(String title, IconData icon, bool isDark, {required String tooltip, required VoidCallback onAdd}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue, size: 20),
            onPressed: onAdd,
            tooltip: tooltip,
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required String id,
    required String title,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    bool showArrow = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected 
            ? AppColors.primaryBlue.withValues(alpha: 0.1) 
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white10 : AppColors.borderLight),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        title: Text(title, style: GoogleFonts.cairo(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primaryBlue : null,
          fontSize: 13,
        )),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_note_rounded, size: 18, color: Colors.blue), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), onPressed: onDelete),
            if (showArrow) Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey[400]),
          ],
        ),
      ),
    );
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

  Widget _emptyState(String message, bool isDark) {
    return Center(
      child: Text(message, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
    );
  }

  // --- Dialogs (Adapted from original) ---

  void _showAddTopicDialog(BuildContext context, String? parentId, String type) {
    final nameController = TextEditingController();
    final label = type == 'chapter' ? 'فصل' : 'درس';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة $label جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: 'الاسم', labelStyle: GoogleFonts.cairo()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _dbService.addTopic(widget.subjectId, parentId, {
                  'name': nameController.text.trim(),
                  'type': type,
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditTopicDialog(String id, Map<String, dynamic> data, String label) async {
    final nameController = TextEditingController(text: data['name']);
    String currentType = data['type'] ?? (label == 'فصل' ? 'chapter' : 'lesson');
    String? currentParentId = data['parentId'];

    // Fetch chapters for the parent dropdown
    final chaptersSnap = await FirebaseFirestore.instance
        .collection(DatabaseService.colTopics)
        .where('subjectId', isEqualTo: widget.subjectId)
        .where('type', isEqualTo: 'chapter')
        .get();
    
    final chapters = chaptersSnap.docs.where((doc) => doc.id != id).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تعديل $label', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'الاسم', 
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: currentType,
                  decoration: InputDecoration(
                    labelText: 'النوع', 
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'chapter', child: Text('فصل رئيسي', style: GoogleFonts.cairo())),
                    DropdownMenuItem(value: 'lesson', child: Text('درس فرعي', style: GoogleFonts.cairo())),
                  ],
                  onChanged: (val) => setDialogState(() {
                    currentType = val!;
                    if (currentType == 'chapter') currentParentId = null;
                  }),
                ),
                if (currentType == 'lesson') ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String?>(
                    value: currentParentId,
                    decoration: InputDecoration(
                      labelText: 'الفصل التابع له', 
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('اختر فصلاً...', style: TextStyle(color: Colors.grey))),
                      ...chapters.map((doc) => DropdownMenuItem(
                        value: doc.id,
                        child: Text(doc.data()['name'] ?? '', style: GoogleFonts.cairo()),
                      )),
                    ],
                    onChanged: (val) => setDialogState(() => currentParentId = val),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                if (currentType == 'lesson' && currentParentId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('يرجى اختيار الفصل التابع له', style: GoogleFonts.cairo())),
                  );
                  return;
                }

                await _dbService.updateDoc(DatabaseService.colTopics, id, {'name': name});
                
                // If type or parent changed, use moveTopic
                if (currentType != data['type'] || currentParentId != data['parentId']) {
                  await _dbService.moveTopic(id, currentParentId, currentType);
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: Text('حفظ التغييرات', style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت متأكد من حذف ($name)؟\nسيتم حذف جميع المحتويات المرتبطة.', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await _dbService.deleteDoc(DatabaseService.colTopics, id);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('حذف', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
