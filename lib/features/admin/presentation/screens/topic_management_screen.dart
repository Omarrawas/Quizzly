import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/presentation/widgets/unified_lesson_editor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quizzly/features/admin/presentation/screens/lesson_management_screen.dart';

class TopicManagementScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final List<String> breadcrumbs;
  final String sectionId;
  final String sectionName;
  final String? referenceSubjectId;

  const TopicManagementScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.breadcrumbs,
    required this.sectionId,
    required this.sectionName,
    this.referenceSubjectId,
  });

  @override
  State<TopicManagementScreen> createState() => _TopicManagementScreenState();
}

class _TopicManagementScreenState extends State<TopicManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  late String _resolvedSubjectId;

  num _readOrder(Map<String, dynamic> data) {
    final value = data['order'];
    return value is num ? value : 0;
  }

  @override
  void initState() {
    super.initState();
    _resolvedSubjectId = widget.referenceSubjectId ?? widget.subjectId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'إدارة الفصول والدروس - ${widget.sectionName}',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (widget.referenceSubjectId != null) _buildWarningBanner(isDark),
          Expanded(child: _buildChaptersList(isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTopicDialog(context, null, 'chapter'),
        icon: const Icon(Icons.create_new_folder_rounded, color: Colors.white),
        label: Text(
          'إضافة فصل جديد',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildWarningBanner(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'تنبيه: هذه المادة تستعير محتواها بالكامل. أي تعديلات أو إضافات هنا ستؤثر على المادة المرجعية الأصلية وكافة المواد المرتبطة بها.',
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.orange[200] : Colors.orange[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getTopics(
        _resolvedSubjectId,
        sectionId: widget.sectionId,
        parentId: null,
        type: 'chapter',
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aOrder = _readOrder(aData);
            final bOrder = _readOrder(bData);
            
            if (aOrder != bOrder) {
              return aOrder.compareTo(bOrder);
            }
            
            final aTime = (aData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bTime = (bData['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return aTime.compareTo(bTime);
          });

        if (docs.isEmpty) {
          return _buildEmptyState(
            'لا توجد فصول مضافة بعد. اضغط على زر الإضافة بالأسفل لإنشاء فصل.',
            Icons.folder_open_rounded,
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 88, top: 12),
          itemCount: docs.length,
          onReorder: (oldIndex, newIndex) => _handleChapterReorder(docs, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final id = doc.id;
            final name = data['name'] ?? '';

            return _ChapterCard(
              key: ValueKey(id),
              chapterId: id,
              chapterName: name,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LessonManagementScreen(
                      subjectId: _resolvedSubjectId,
                      subjectName: widget.subjectName,
                      sectionId: widget.sectionId,
                      sectionName: widget.sectionName,
                      chapterId: id,
                      chapterName: name,
                      breadcrumbs: [...widget.breadcrumbs, name],
                    ),
                  ),
                );
              },
              chapterTitleWidget: TexViewWidget(
                text: name,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              chapterData: data,
              isDark: isDark,
              onAddLesson: () => _showAddTopicDialog(context, id, 'lesson'),
              onEditChapter: () => _showEditTopicDialog(id, data, 'فصل'),
              onDeleteChapter: () => _confirmDelete(id, name),
              index: index,
            );
          },
        );
      },
    );
  }

  Future<void> _handleChapterReorder(List<QueryDocumentSnapshot> docs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final List<String> ids = docs.map((d) => d.id).toList();
    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);
    try {
      await _dbService.updateOrder(DatabaseService.colTopics, ids);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحديث الترتيب: $e', style: GoogleFonts.cairo())),
        );
      }
    }
  }

  Widget _buildErrorState(String error) {
    bool isIndexError = error.contains('index');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isIndexError ? Icons.bolt_rounded : Icons.error_outline_rounded,
              color: Colors.amber[700],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              isIndexError ? 'جاري تجهيز قاعدة البيانات...' : 'حدث خطأ ما',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isIndexError
                  ? 'يتم حالياً إنشاء الفهارس المطلوبة (Indexes). قد يستغرق هذا بضع دقائق لأول مرة فقط.'
                  : error,
              style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 13),
            ),
            if (isIndexError) ...[
              const SizedBox(height: 20),
              const SizedBox(width: 120, child: LinearProgressIndicator()),
              const SizedBox(height: 12),
              Text(
                'يرجى عمل Hot Restart بعد دقيقتين',
                style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey[200], size: 64),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.cairo(
              color: Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- Dialogs (Adapted from original) ---

  void _showAddTopicDialog(
    BuildContext context,
    String? parentId,
    String type,
  ) {
    if (type == 'lesson' && parentId != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => UnifiedLessonEditorSheet(
          subjectId: _resolvedSubjectId,
          sectionId: widget.sectionId,
          type: 'lesson',
          parentId: parentId,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final label = type == 'chapter' ? 'فصل' : 'درس';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'إضافة $label جديد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'الاسم',
            labelStyle: GoogleFonts.cairo(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _dbService.addTopic(
                  _resolvedSubjectId,
                  widget.sectionId,
                  parentId,
                  {'name': nameController.text.trim(), 'type': type},
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditTopicDialog(
    String id,
    Map<String, dynamic> data,
    String label,
  ) async {
    final nameController = TextEditingController(text: data['name']);
    String currentType =
        data['type'] ?? (label == 'فصل' ? 'chapter' : 'lesson');
    String? currentParentId = data['parentId'];

    // Fetch chapters for the parent dropdown
    final chaptersSnap = await FirebaseFirestore.instance
        .collection(DatabaseService.colTopics)
        .where('subjectId', isEqualTo: _resolvedSubjectId)
        .where('sectionId', isEqualTo: widget.sectionId)
        .where('type', isEqualTo: 'chapter')
        .get();

    final chapters = chaptersSnap.docs.where((doc) => doc.id != id).toList();

    if (!mounted) {
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'تعديل $label',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'الاسم',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: currentType,
                  decoration: InputDecoration(
                    labelText: 'النوع',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  items: [
                    DropdownMenuItem(
                      value: 'chapter',
                      child: Text(
                        'فصل رئيسي',
                        style: GoogleFonts.cairo(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'lesson',
                      child: Text(
                        'درس فرعي',
                        style: GoogleFonts.cairo(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) => setDialogState(() {
                    currentType = val!;
                    if (currentType == 'chapter') currentParentId = null;
                  }),
                ),
                if (currentType == 'lesson') ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String?>(
                    initialValue: currentParentId,
                    decoration: InputDecoration(
                      labelText: 'الفصل التابع له',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    dropdownColor: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'اختر فصلاً...',
                          style: GoogleFonts.cairo(color: Colors.grey),
                        ),
                      ),
                      ...chapters.map(
                        (doc) => DropdownMenuItem(
                          value: doc.id,
                          child: Text(
                            doc.data()['name'] ?? '',
                            style: GoogleFonts.cairo(
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => currentParentId = val),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }

                if (currentType == 'lesson' && currentParentId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'يرجى اختيار الفصل التابع له',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                  );
                  return;
                }

                await _dbService.updateDoc(DatabaseService.colTopics, id, {
                  'name': name,
                });

                // If type or parent changed, use moveTopic
                if (currentType != data['type'] ||
                    currentParentId != data['parentId']) {
                  await _dbService.moveTopic(id, currentParentId, currentType);
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                'حفظ التغييرات',
                style: GoogleFonts.cairo(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, String name) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    // Quick role check
    final bool isSuper = await _dbService.isSuperAdmin(currentUserId);
    
    if (!isSuper) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('عذراً، حذف الفصول والدروس متاح فقط للـ Super Admin', style: GoogleFonts.cairo()),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تأكيد الحذف النهائي',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(
          'تنبيه هام: هل أنت متأكد من حذف ($name)؟\n\nبصفتك سوبـر أدمن، سيؤدي هذا الإجراء إلى حذف كافة الأسئلة والمحتويات الموجودة داخل هذا القسم بشكل نهائي من قاعدة البيانات ولا يمكن التراجع عنها.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final navigator = Navigator.of(context);
              try {
                // Determine if it's a chapter or lesson based on context (here we simplified deleteTopicCascade logic)
                // Actually, let's fetch the type to be sure
                final doc = await FirebaseFirestore.instance.collection(DatabaseService.colTopics).doc(id).get();
                final type = doc.data()?['type'] ?? 'lesson';
                
                await _dbService.deleteTopicCascade(id, type);
                
                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('تم حذف القسم وكافة ملحقاته بنجاح', style: GoogleFonts.cairo()),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('فشل الحذف: $e', style: GoogleFonts.cairo()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('حذف نهائي', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final String chapterId;
  final String chapterName;
  final Map<String, dynamic> chapterData;
  final bool isDark;
  final VoidCallback onAddLesson;
  final VoidCallback onEditChapter;
  final VoidCallback onDeleteChapter;
  final VoidCallback onTap;
  final Widget chapterTitleWidget;
  final int index;

  const _ChapterCard({
    super.key,
    required this.chapterId,
    required this.chapterName,
    required this.chapterData,
    required this.isDark,
    required this.onAddLesson,
    required this.onEditChapter,
    required this.onDeleteChapter,
    required this.onTap,
    required this.chapterTitleWidget,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[200]!,
        ),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_indicator_rounded,
                color: isDark ? Colors.white24 : Colors.grey[300],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.folder_rounded,
              color: AppColors.primaryBlue,
              size: 28,
            ),
          ],
        ),
        title: chapterTitleWidget,
        subtitle: Text(
          'اضغط لاستعراض الدروس',
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 22),
              onPressed: onEditChapter,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
              onPressed: onDeleteChapter,
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
