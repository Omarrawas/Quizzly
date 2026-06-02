import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/rich_text_editor.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/presentation/screens/theoretical_section_management_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/theoretical_lesson_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
            final aOrder = _readOrder(a.data() as Map<String, dynamic>);
            final bOrder = _readOrder(b.data() as Map<String, dynamic>);
            return aOrder.compareTo(bOrder);
          });

        if (docs.isEmpty) {
          return _buildEmptyState(
            'لا توجد فصول مضافة بعد. اضغط على زر الإضافة بالأسفل لإنشاء فصل.',
            Icons.folder_open_rounded,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88, top: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final id = doc.id;
            final name = data['name'] ?? '';

            return _ChapterCard(
              chapterId: id,
              chapterName: name,
              chapterData: data,
              isDark: isDark,
              onAddLesson: () => _showAddTopicDialog(context, id, 'lesson'),
              onEditChapter: () => _showEditTopicDialog(id, data, 'فصل'),
              onDeleteChapter: () => _confirmDelete(id, name),
              lessonsList: _buildNestedLessonsList(id, isDark),
            );
          },
        );
      },
    );
  }

  Widget _buildNestedLessonsList(String chapterId, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getTopics(
        _resolvedSubjectId,
        sectionId: widget.sectionId,
        parentId: chapterId,
        type: 'lesson',
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'خطأ: ${snapshot.error}',
              style: GoogleFonts.cairo(color: Colors.red, fontSize: 12),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 2,
                child: LinearProgressIndicator(),
              ),
            ),
          );
        }

        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aOrder = _readOrder(a.data() as Map<String, dynamic>);
            final bOrder = _readOrder(b.data() as Map<String, dynamic>);
            return aOrder.compareTo(bOrder);
          });

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Text(
                'لا توجد دروس في هذا الفصل حالياً.',
                style: GoogleFonts.cairo(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: docs.map((doc) {
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
                onEditContent: () => _showEditLessonContentDialog(id, data),
                onPreview: () => _previewLesson(id, name, data),
                onDelete: () => _confirmDelete(id, name),
                data: data,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildListTile({
    required String id,
    required String title,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    VoidCallback? onEditContent,
    VoidCallback? onPreview,
    required VoidCallback onDelete,
    bool showArrow = false,
    Map<String, dynamic>? data, // Added to check for isFree
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryBlue.withValues(alpha: 0.1)
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryBlue
              : (isDark ? Colors.white10 : AppColors.borderLight),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 13,
                ),
              ),
            ),
            if (data != null && data['isFree'] == true)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 4,
              onSelected: (value) {
                switch (value) {
                  case 'preview':
                    onPreview?.call();
                    break;
                  case 'edit_content':
                    onEditContent?.call();
                    break;
                  case 'edit':
                    onEdit();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (onPreview != null)
                  PopupMenuItem(
                    value: 'preview',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.remove_red_eye_rounded,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'معاينة الدرس',
                          style: GoogleFonts.cairo(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                if (onEditContent != null)
                  PopupMenuItem(
                    value: 'edit_content',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.video_collection_rounded,
                          size: 18,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تعديل المحتوى النظري',
                          style: GoogleFonts.cairo(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تعديل الاسم/النوع',
                        style: GoogleFonts.cairo(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'حذف',
                        style: GoogleFonts.cairo(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showArrow) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: Colors.grey[400],
              ),
            ],
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

  void _previewLesson(
    String lessonId,
    String lessonName,
    Map<String, dynamic> data,
  ) {
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
  void _showEditLessonContentDialog(String id, Map<String, dynamic> data) {
    final descriptionController = TextEditingController(
      text: data['description'] ?? '',
    );
    final videoUrlController = TextEditingController(
      text: data['videoUrl'] ?? '',
    );
    final imageUrlsController = TextEditingController(
      text: (data['imageUrls'] as List<dynamic>?)?.join('\n') ?? '',
    );
    bool isFree = data['isFree'] == true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'تعديل المحتوى النظري للدرس',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0F172A)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'درس مجاني',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'يمكن للطلاب مشاهدة هذا الدرس بدون اشتراك',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    value: isFree,
                    activeThumbColor: Colors.green,
                    onChanged: (val) => setDialogState(() => isFree = val),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'الشرح النظري',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                RichTextEditor(
                  initialHtml: descriptionController.text,
                  placeholder: 'اكتب الشرح النظري هنا...',
                  height: 250,
                  onContentChanged: (html) {
                    descriptionController.text = html;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: videoUrlController,
                  decoration: InputDecoration(
                    labelText: 'رابط الفيديو (YouTube/Direct)',
                    prefixIcon: const Icon(Icons.link_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: imageUrlsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'روابط الصور (رابط في كل سطر)',
                    prefixIcon: const Icon(Icons.image_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
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
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final imageUrls = imageUrlsController.text
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                await _dbService.updateDoc(DatabaseService.colTopics, id, {
                  'description': descriptionController.text.trim(),
                  'videoUrl': videoUrlController.text.trim(),
                  'imageUrls': imageUrls,
                  'mediaType': videoUrlController.text.isNotEmpty
                      ? 'video'
                      : (imageUrls.isNotEmpty ? 'images' : 'text'),
                  'isFree': isFree,
                  'lastUpdated': DateTime.now().toString().split(' ')[0],
                });

                if (context.mounted) Navigator.pop(context);
              },
              child: Text('حفظ المحتوى', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterCard extends StatefulWidget {
  final String chapterId;
  final String chapterName;
  final Map<String, dynamic> chapterData;
  final bool isDark;
  final VoidCallback onAddLesson;
  final VoidCallback onEditChapter;
  final VoidCallback onDeleteChapter;
  final Widget lessonsList;

  const _ChapterCard({
    required this.chapterId,
    required this.chapterName,
    required this.chapterData,
    required this.isDark,
    required this.onAddLesson,
    required this.onEditChapter,
    required this.onDeleteChapter,
    required this.lessonsList,
  });

  @override
  State<_ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<_ChapterCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey[200]!,
        ),
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            key: PageStorageKey<String>(widget.chapterId),
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            leading: const Icon(
              Icons.folder_rounded,
              color: AppColors.primaryBlue,
              size: 24,
            ),
            title: Text(
              widget.chapterName,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.green,
                    size: 20,
                  ),
                  tooltip: 'إضافة درس',
                  onPressed: widget.onAddLesson,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                  tooltip: 'تعديل الفصل',
                  onPressed: widget.onEditChapter,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  tooltip: 'حذف الفصل',
                  onPressed: widget.onDeleteChapter,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
            children: [widget.lessonsList],
          ),
        ),
      ),
    );
  }
}
