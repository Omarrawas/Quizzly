import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/admin/presentation/screens/static_exam_question_selector.dart';

class ExamManagementScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final List<String> breadcrumbs;

  const ExamManagementScreen({
    super.key,
    required this.subjectId,
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
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
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
        label: Text('إضافة اختبار', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
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
      stream: _dbService.getExams(widget.subjectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return _emptyState('حدث خطأ أثناء جلب الاختبارات: ${snapshot.error}', isDark, isError: true);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState('لا توجد اختبارات حالياً', isDark);
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final id = docs[index].id;
            final config = ExamConfig.fromFirestore(docs[index]);
            return _buildExamCard(id, config, isDark);
          },
        );
      },
    );
  }

  Widget _buildExamCard(String id, ExamConfig config, bool isDark) {

    return Container(
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
                    config.type == ExamType.bank ? 'بنك' : 'دورة',
                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: config.type == ExamType.bank ? Colors.purple : Colors.blue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    config.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
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
                  Text('${config.totalQuestions} سؤال', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 16),
                  Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${config.durationSeconds ~/ 60} دقيقة', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
          if (config.type == ExamType.dora)
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
                          initialSelectedIds: config.staticQuestionIds,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: Text('تحديد أسئلة الدورة (${config.staticQuestionIds.length})', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
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
              style: GoogleFonts.cairo(color: isError ? Colors.red : AppColors.textSecondary, fontSize: 11),
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
        content: Text(message, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }

  void _showAddExamDialog(BuildContext context, {ExamConfig? existingConfig, String? examId}) {
    final isEdit = existingConfig != null;
    final titleController = TextEditingController(text: existingConfig?.title);
    final questionsCountController = TextEditingController(text: existingConfig?.totalQuestions.toString() ?? '20');
    final durationController = TextEditingController(text: (existingConfig != null ? existingConfig.durationSeconds ~/ 60 : 20).toString());
    final scoreController = TextEditingController(text: existingConfig?.passingScore.toString() ?? '60');
    
    ExamType selectedType = existingConfig?.type ?? ExamType.bank;
    List<String> selectedTopics = existingConfig?.generationRules?.topicIds ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? 'تعديل الاختبار' : 'إضافة اختبار جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: 'عنوان الاختبار', labelStyle: GoogleFonts.cairo(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: questionsCountController,
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final q = int.tryParse(v) ?? 0;
                            setDialogState(() {
                              durationController.text = q.toString(); // 1 minute per question
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'عدد الأسئلة', 
                            labelStyle: GoogleFonts.cairo(), 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            suffixText: 'سؤال',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: durationController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'المدة (دقائق)', 
                            labelStyle: GoogleFonts.cairo(), 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            suffixText: 'دقيقة',
                            helperText: 'يتم حسابها تلقائياً',
                            helperStyle: GoogleFonts.cairo(fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: scoreController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'درجة النجاح المئوية (مثال: 60)', labelStyle: GoogleFonts.cairo(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                  Text('نوع الاختبار', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                  RadioGroup<ExamType>(
                    groupValue: selectedType,
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<ExamType>(
                            title: Text('بنك أسئلة', style: GoogleFonts.cairo(fontSize: 12)),
                            value: ExamType.bank,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<ExamType>(
                            title: Text('دورة', style: GoogleFonts.cairo(fontSize: 12)),
                            value: ExamType.dora,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedType == ExamType.bank) ...[
                    const Divider(),
                    Text('سيتم توليد الأسئلة تلقائياً من بنك الأسئلة', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                
                final int duration = (int.tryParse(durationController.text) ?? 20) * 60;
                final int totalQ = int.tryParse(questionsCountController.text) ?? 20;
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
                  staticQuestionIds: existingConfig?.staticQuestionIds ?? [],
                  generationRules: selectedType == ExamType.bank ? GenerationRules(
                    topicIds: selectedTopics,
                  ) : null,
                );

                try {
                  String newExamId = examId ?? '';
                  if (isEdit) {
                    await _dbService.updateDoc(DatabaseService.colExams, examId!, config.toMap());
                  } else {
                    final docRef = await FirebaseFirestore.instance.collection(DatabaseService.colExams).add(config.toMap());
                    newExamId = docRef.id;
                  }
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    _showStatusSnackBar(isEdit ? 'تم تحديث الاختبار بنجاح' : 'تمت إضافة الاختبار بنجاح', isError: false);
                    
                    // Auto-navigate to selection if it's a new dora exam
                    if (!isEdit && selectedType == ExamType.dora) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StaticExamQuestionSelector(
                            examId: newExamId,
                            examTitle: config.title,
                            subjectId: widget.subjectId,
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
              child: Text(isEdit ? 'تحديث' : 'إضافة', style: GoogleFonts.cairo()),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت متأكد من حذف اختبار ($title)؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
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
            child: Text('حذف', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
