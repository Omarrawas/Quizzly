import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/admin/presentation/screens/static_exam_question_selector.dart';

class ExamManagementScreen extends StatefulWidget {
  final String subjectId;
  final String sectionId;
  final String subjectName;
  final List<String> breadcrumbs;

  const ExamManagementScreen({
    super.key,
    required this.subjectId,
    required this.sectionId,
    required this.subjectName,
    required this.breadcrumbs,
  });

  @override
  State<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends State<ExamManagementScreen> {
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'الاختبارات - ${widget.subjectName}',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(isDark),
          Expanded(child: _buildExamsList(isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExamDialog(context),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('إضافة اختبار', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBreadcrumbs(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: widget.breadcrumbs.asMap().entries.map((entry) {
            return Row(
              children: [
                if (entry.key > 0) Icon(Icons.chevron_left_rounded, size: 16, color: Colors.grey[400]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.value,
                    style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildExamsList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getExams(widget.subjectId, sectionId: widget.sectionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return _emptyState('حدث خطأ أثناء جلب الاختبارات: ${snapshot.error}', isDark, isError: true);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState('لا توجد اختبارات حالياً', isDark);
        }

        final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final int orderA = dataA['order'] ?? 999999;
          final int orderB = dataB['order'] ?? 999999;
          if (orderA != orderB) {
            return orderA.compareTo(orderB);
          }
          final Timestamp? timeA = dataA['createdAt'] as Timestamp?;
          final Timestamp? timeB = dataB['createdAt'] as Timestamp?;
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          return timeB.compareTo(timeA); // Descending (newest first)
        });

        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final id = docs[index].id;
            final config = ExamConfig.fromFirestore(docs[index]);
            return _buildExamCard(id, config, isDark, index);
          },
          onReorder: (oldIndex, newIndex) async {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            if (oldIndex == newIndex) return;

            final items = List<QueryDocumentSnapshot>.from(docs);
            final item = items.removeAt(oldIndex);
            items.insert(newIndex, item);

            final ids = items.map((doc) => doc.id).toList();

            try {
              await _dbService.updateOrder(DatabaseService.colExams, ids);
              _showStatusSnackBar('تم تحديث الترتيب بنجاح', isError: false);
            } catch (e) {
              _showStatusSnackBar('فشل تحديث الترتيب: $e', isError: true);
            }
          },
        );
      },
    );
  }

  Widget _buildExamCard(String id, ExamConfig config, bool isDark, int index) {

    return Container(
      key: ValueKey(id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: config.type == ExamType.bank ? Colors.purple.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    config.type == ExamType.bank ? 'اختبار' : 'دورة',
                    style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.bold, color: config.type == ExamType.bank ? Colors.purple : Colors.blue),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: config.isFree ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    config.isFree ? 'مجاني' : 'مدفوع',
                    style: GoogleFonts.tajawal(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: config.isFree ? Colors.green : Colors.orange[800],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    config.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${config.totalQuestions} سؤال', style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 16),
                  Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${config.durationSeconds ~/ 60} دقيقة', style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.drag_handle_rounded, color: Colors.grey),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue),
                  onPressed: () => _showAddExamDialog(context, existingConfig: config, examId: id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () => _confirmDelete(id, config.title),
                ),
              ],
            ),
          ),
          if (config.type == ExamType.dora || config.type == ExamType.bank)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StaticExamQuestionSelector(
                          examId: id,
                          examTitle: config.title,
                          subjectId: widget.subjectId,
                          sectionId: widget.sectionId,
                          initialSelectedIds: config.staticQuestionIds,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: Text(
                    config.type == ExamType.dora 
                        ? 'تحديد أسئلة الدورة (${config.staticQuestionIds.length})'
                        : 'تحديد أسئلة الاختبار (${config.staticQuestionIds.length})', 
                    style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.bold)
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, bool isDark, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.assignment_outlined,
              size: 48,
              color: isError ? Colors.red.withValues(alpha: 0.5) : (isDark ? Colors.white24 : Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            SelectableText(
              message,
              style: GoogleFonts.tajawal(color: isError ? Colors.red : AppColors.textSecondary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message, 
          style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.bold, color: isError ? Colors.white : const Color(0xFF18191D))
        ),
        backgroundColor: isError ? const Color(0xFFFF4C6A) : const Color(0xFF7DFFA2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }

  void _showAddExamDialog(BuildContext context, {ExamConfig? existingConfig, String? examId}) {
    final isEdit = existingConfig != null;
    final titleController = TextEditingController(text: existingConfig?.title);
    final scoreController = TextEditingController(text: existingConfig?.passingScore.toString() ?? '60');
    
    ExamType selectedType = existingConfig?.type ?? ExamType.dora;
    bool isFree = existingConfig?.isFree ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF222329),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEdit ? 'تعديل الاختبار' : 'إضافة اختبار جديد', 
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: GoogleFonts.tajawal(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'عنوان الاختبار', 
                      labelStyle: GoogleFonts.tajawal(color: Colors.white70), 
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2D2E36)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF6E56FF)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF18191D),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: scoreController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.tajawal(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'درجة النجاح المئوية (مثال: 60)', 
                      labelStyle: GoogleFonts.tajawal(color: Colors.white70), 
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2D2E36)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF6E56FF)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF18191D),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'نوع الاختبار', 
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<ExamType>(
                    groupValue: selectedType,
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<ExamType>(
                            title: Text('دورة', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white)),
                            value: ExamType.dora,
                            activeColor: const Color(0xFF6E56FF),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<ExamType>(
                            title: Text('اختبار', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white)),
                            value: ExamType.bank,
                            activeColor: const Color(0xFF6E56FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(
                      'اختبار مجاني', 
                      style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                    subtitle: Text(
                      'إذا كان مفعلاً، سيتمكن جميع الطلاب من تقديم الاختبار', 
                      style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white54)
                    ),
                    value: isFree,
                    activeThumbColor: const Color(0xFF7DFFA2),
                    activeTrackColor: const Color(0xFF6E56FF).withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.grey[400],
                    inactiveTrackColor: Colors.grey[800],
                    onChanged: (v) => setDialogState(() => isFree = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text(
                'إلغاء', 
                style: GoogleFonts.tajawal(color: Colors.white70, fontWeight: FontWeight.bold)
              )
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E56FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                
                final int duration = existingConfig?.durationSeconds ?? 0;
                final int totalQ = existingConfig?.totalQuestions ?? 0;
                final double score = double.tryParse(scoreController.text) ?? 60.0;

                final config = ExamConfig(
                  id: examId,
                  title: titleController.text.trim(),
                  category: titleController.text.trim(),
                  type: selectedType,
                  durationSeconds: duration,
                  totalQuestions: totalQ,
                  passingScore: score,
                  subjectId: widget.subjectId,
                  sectionId: widget.sectionId,
                  staticQuestionIds: existingConfig?.staticQuestionIds ?? [],
                  generationRules: null,
                  isFree: isFree,
                );

                try {
                  String newExamId = examId ?? '';
                  if (isEdit) {
                    await _dbService.updateDoc(DatabaseService.colExams, examId!, config.toMap());
                  } else {
                    final docRef = await _dbService.addExam(config.toMap());
                    newExamId = docRef.id;
                  }
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    _showStatusSnackBar(isEdit ? 'تم تحديث الاختبار بنجاح' : 'تمت إضافة الاختبار بنجاح', isError: false);
                    
                    // Auto-navigate to selection if it's a new exam
                    if (!isEdit && (selectedType == ExamType.dora || selectedType == ExamType.bank)) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StaticExamQuestionSelector(
                            examId: newExamId,
                            examTitle: config.title,
                            subjectId: widget.subjectId,
                            sectionId: widget.sectionId,
                            initialSelectedIds: const [],
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) _showStatusSnackBar('فشل العملية: $e', isError: true);
                }
              },
              child: Text(isEdit ? 'تحديث' : 'إضافة', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222329),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تأكيد الحذف', 
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: const Color(0xFFFF4C6A), fontSize: 18)
        ),
        content: Text(
          'هل أنت متأكد من حذف اختبار ($title)؟', 
          style: GoogleFonts.tajawal(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('إلغاء', style: GoogleFonts.tajawal(color: Colors.white70))
          ),
          TextButton(
            onPressed: () async {
              try {
                await _dbService.deleteDoc(DatabaseService.colExams, id);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showStatusSnackBar('تم حذف الاختبار بنجاح', isError: false);
                }
              } catch (e) {
                if (context.mounted) _showStatusSnackBar('فشل الحذف: $e', isError: true);
              }
            },
            child: Text('حذف', style: GoogleFonts.tajawal(color: const Color(0xFFFF4C6A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
