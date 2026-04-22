import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class TheoreticalSectionManagementScreen extends StatefulWidget {
  final String sectionPath;
  final String sectionName;
  final List<String> breadcrumbs;

  const TheoreticalSectionManagementScreen({
    super.key,
    required this.sectionPath,
    required this.sectionName,
    required this.breadcrumbs,
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
          widget.sectionName,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
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
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getQuestions(widget.sectionPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey[400]),
                const SizedBox(height: 16),
                Text('لا توجد أسئلة في هذا القسم حالياً', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            return _buildQuestionCard(id, data, isDark);
          },
        );
      },
    );
  }

  Widget _buildQuestionCard(String id, Map<String, dynamic> data, bool isDark) {
    final type = data['type'] == 'mcq' ? 'أتمتة' : 'مقالي';
    final questionText = data['text'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: data['type'] == 'mcq' ? Colors.blue.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                type,
                style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: data['type'] == 'mcq' ? Colors.blue : Colors.orange),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                questionText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 22), onPressed: () => _showEditQuestionDialog(id, data)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22), onPressed: () => _confirmDelete(id, questionText)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نص السؤال:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                Text(questionText, style: GoogleFonts.cairo()),
                const SizedBox(height: 16),
                if (data['type'] == 'mcq') ...[
                  Text('الخيارات:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ...(data['options'] as List? ?? []).map((opt) {
                    final isCorrect = opt['id'] == data['correctOptionId'];
                    return Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(isCorrect ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: isCorrect ? Colors.green : Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(opt['text'] ?? '', style: GoogleFonts.cairo(fontSize: 13))),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  Text('الإجابة النموذجية:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  Text(data['essayAnswer'] ?? 'لا توجد إجابة محددة', style: GoogleFonts.cairo()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddQuestionDialog(BuildContext context) {
    _showQuestionDialog();
  }

  void _showEditQuestionDialog(String id, Map<String, dynamic> currentData) {
    _showQuestionDialog(id: id, currentData: currentData);
  }

  void _showQuestionDialog({String? id, Map<String, dynamic>? currentData}) {
    final bool isEdit = id != null;
    QuestionType selectedType = currentData?['type'] == 'essay' ? QuestionType.essay : QuestionType.mcq;
    final textController = TextEditingController(text: currentData?['text']);
    final essayAnswerController = TextEditingController(text: currentData?['essayAnswer']);
    
    // MCQ Options
    List<Map<String, String>> options = (currentData?['options'] as List? ?? [])
        .map((e) => {'id': e['id'].toString(), 'text': e['text'].toString()})
        .toList();
    if (options.isEmpty && selectedType == QuestionType.mcq) {
      options = [{'id': 'a', 'text': ''}, {'id': 'b', 'text': ''}, {'id': 'c', 'text': ''}, {'id': 'd', 'text': ''}];
    }
    String? correctOptionId = currentData?['correctOptionId'] ?? (options.isNotEmpty ? options[0]['id'] : null);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? 'تعديل سؤال' : 'إضافة سؤال جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نوع السؤال', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<QuestionType>(
                          title: Text('أتمتة', style: GoogleFonts.cairo(fontSize: 12)),
                          value: QuestionType.mcq,
                          groupValue: selectedType,
                          onChanged: (v) => setDialogState(() => selectedType = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<QuestionType>(
                          title: Text('مقالي', style: GoogleFonts.cairo(fontSize: 12)),
                          value: QuestionType.essay,
                          groupValue: selectedType,
                          onChanged: (v) => setDialogState(() => selectedType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'نص السؤال',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedType == QuestionType.mcq) ...[
                    Text('الخيارات (حدد الخيار الصحيح)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ...options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final opt = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: opt['id']!,
                              groupValue: correctOptionId,
                              onChanged: (v) => setDialogState(() => correctOptionId = v),
                            ),
                            Expanded(
                              child: TextField(
                                onChanged: (v) => opt['text'] = v,
                                controller: TextEditingController(text: opt['text'])..selection = TextSelection.fromPosition(TextPosition(offset: opt['text']!.length)),
                                decoration: InputDecoration(
                                  hintText: 'الخيار ${opt['id']!.toUpperCase()}',
                                  hintStyle: GoogleFonts.cairo(fontSize: 12),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    TextField(
                      controller: essayAnswerController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'الإجابة النموذجية (اختياري)',
                        labelStyle: GoogleFonts.cairo(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              onPressed: () async {
                if (textController.text.trim().isEmpty) return;
                
                final Map<String, dynamic> questionData = {
                  'text': textController.text.trim(),
                  'type': selectedType == QuestionType.mcq ? 'mcq' : 'essay',
                };

                if (selectedType == QuestionType.mcq) {
                  questionData['options'] = options;
                  questionData['correctOptionId'] = correctOptionId;
                } else {
                  questionData['essayAnswer'] = essayAnswerController.text.trim();
                }

                if (isEdit) {
                  await _dbService.updateDoc('${widget.sectionPath}/questions/$id', questionData);
                } else {
                  await _dbService.addQuestion(widget.sectionPath, questionData);
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: Text(isEdit ? 'حفظ' : 'إضافة', style: GoogleFonts.cairo()),
            ),
          ],
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
              await _dbService.deleteDoc('${widget.sectionPath}/questions/$id');
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('حذف', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
