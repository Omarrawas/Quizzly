import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/admin/presentation/screens/bulk_upload_screen.dart';
import 'package:quizzly/features/admin/domain/services/bulk_upload_service.dart';
import 'package:quizzly/features/admin/presentation/screens/question_management_screen.dart';


class TheoreticalSectionManagementScreen extends StatefulWidget {
  final String? sectionId;
  final String? sectionName;
  final String subjectId;
  final List<String> breadcrumbs;
  final String? lessonId;
  final String? lessonName;

  const TheoreticalSectionManagementScreen({
    super.key,
    this.sectionId,
    this.sectionName,
    required this.subjectId,
    required this.breadcrumbs,
    this.lessonId,
    this.lessonName,
  });

  @override
  State<TheoreticalSectionManagementScreen> createState() => _TheoreticalSectionManagementScreenState();
}

class _TheoreticalSectionManagementScreenState extends State<TheoreticalSectionManagementScreen> {
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
          widget.lessonName != null 
              ? 'أسئلة: ${widget.lessonName}' 
              : (widget.sectionName ?? 'بنك الأسئلة'),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'تصدير الأسئلة (CSV)',
            onPressed: _exportCSV,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'رفع أسئلة (CSV)',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => BulkUploadScreen(subjectId: widget.subjectId)));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(isDark),
          Expanded(child: _buildQuestionsList(isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddQuestionDialog(context),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('إضافة سؤال', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildQuestionsList(bool isDark) {
    Query query = FirebaseFirestore.instance
        .collection(DatabaseService.colQuestions)
        .where('subjectId', isEqualTo: widget.subjectId);

    if (widget.lessonId != null) {
      query = query.where('topicIds', arrayContains: widget.lessonId);
    } else if (widget.sectionId != null) {
      query = query.where('parentId', isEqualTo: widget.sectionId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return _emptyState('حدث خطأ أثناء جلب الأسئلة: ${snapshot.error}', isDark, isError: true);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState('لا توجد أسئلة في هذا القسم حالياً', isDark);
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            return _buildQuestionCard(id, data, isDark, key: ValueKey(id));
          },
        );
      },
    );
  }

  Widget _buildQuestionCard(String id, Map<String, dynamic> data, bool isDark, {Key? key}) {
    final String typeStr = data['type'] == 'mcq' ? 'أتمتة' : (data['type'] == 'tf' ? 'صح/خطأ' : 'مقالي');
    final Color typeColor = data['type'] == 'mcq' ? Colors.blue : (data['type'] == 'tf' ? Colors.teal : Colors.orange);
    final questionText = data['text'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: ExpansionTile(
        key: PageStorageKey(id),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(typeStr, style: GoogleFonts.cairo(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    questionText,
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data['topicNames'] != null && (data['topicNames'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        (data['topicNames'] as List).join(', '),
                        style: GoogleFonts.cairo(fontSize: 10, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 10),
                if (data['options'] != null) ...[
                  Text('الخيارات:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  ...(data['options'] as List).map((opt) {
                    final isCorrect = (data['correctOptionIds'] as List?)?.contains(opt['id']) ?? (opt['id'] == data['correctOptionId']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green.withValues(alpha: 0.05) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, 
                               size: 16, color: isCorrect ? Colors.green : Colors.grey),
                          const SizedBox(width: 10),
                          Expanded(child: Text(opt['text'] ?? '', style: GoogleFonts.cairo(fontSize: 12))),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    _buildMetaChip(Icons.bar_chart_rounded, data['difficulty'] ?? 'N/A', Colors.blue),
                    const SizedBox(width: 8),
                    _buildMetaChip(Icons.psychology_rounded, _translateCognitiveLevel(data['cognitiveLevel']), Colors.orange),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: Text('تعديل', style: GoogleFonts.cairo()),
                      onPressed: () => _showEditQuestionDialog(id, data),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                      label: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
                      onPressed: () => _confirmDelete(id, questionText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _translateCognitiveLevel(String? c) {
    switch (c) {
      case 'recall': return 'تذكر';
      case 'application': return 'تطبيق';
      case 'understanding':
      default: return 'فهم واستيعاب';
    }
  }

  Widget _buildMetaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showAddQuestionDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionManagementScreen(
          sectionId: widget.sectionId,
          subjectId: widget.subjectId,
          lessonId: widget.lessonId,
          lessonName: widget.lessonName,
        ),
      ),
    );
  }

  void _showEditQuestionDialog(String id, Map<String, dynamic> currentData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionManagementScreen(
          sectionId: widget.sectionId ?? 'global', // Fallback for global bank
          subjectId: widget.subjectId,
          lessonId: widget.lessonId,
          lessonName: widget.lessonName,
          questionId: id,
          currentData: currentData,
        ),
      ),
    );
  }

  void _confirmDelete(String id, String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت متأكد من حذف هذا السؤال؟\n${text.substring(0, text.length > 50 ? 50 : text.length)}...', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              try {
                await _dbService.deleteDoc(DatabaseService.colQuestions, id);
                if (mounted) {
                  navigator.pop();
                  _showStatusSnackBar('تم حذف السؤال بنجاح', isError: false);
                }
              } catch (e) {
                if (mounted) _showStatusSnackBar('فشل الحذف: $e', isError: true);
              }
            },
            child: Text('حذف', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCSV() async {
    try {
      final topicsSnap = await FirebaseFirestore.instance.collection(DatabaseService.colTopics).where('subjectId', isEqualTo: widget.subjectId).get();
      Map<String, String> topicIdToName = {};
      for (var doc in topicsSnap.docs) {
        topicIdToName[doc.id] = doc.data()['name'] ?? '';
      }
      final questionsSnap = await FirebaseFirestore.instance.collection(DatabaseService.colQuestions).where('parentId', isEqualTo: widget.sectionId).get();
      final List<QuizQuestion> questions = questionsSnap.docs.map((doc) => QuizQuestion.fromFirestore(doc)).toList();
      
      if (!mounted) return;

      if (questions.isEmpty) {
        _showStatusSnackBar('لا توجد أسئلة لتصديرها', isError: true);
        return;
      }
      
      final csvContent = BulkUploadService.generateTemplate(questions: questions, topicIdToName: topicIdToName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'questions_${widget.sectionName ?? "global"}_$timestamp';
      
      // إضافة BOM (Byte Order Mark) لضمان قراءة اللغة العربية بشكل صحيح في Excel
      // نستخدم تسلسل البايتات الصريح [0xEF, 0xBB, 0xBF]
      final encodedContent = utf8.encode(csvContent);
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...encodedContent]);
      
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      if (mounted) {
        _showStatusSnackBar('تم حفظ ملف CSV بنجاح', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showStatusSnackBar('فشل التصدير: $e', isError: true);
      }
    }
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

  Widget _emptyState(String message, bool isDark, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.quiz_outlined,
              size: 48,
              color: isError ? Colors.red.withValues(alpha: 0.5) : (isDark ? Colors.white24 : Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.cairo(color: isError ? Colors.red : AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
