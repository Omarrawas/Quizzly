import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/admin/presentation/screens/bulk_upload_screen.dart';

class TheoreticalSectionManagementScreen extends StatefulWidget {
  final String sectionId;
  final String sectionName;
  final String subjectId;
  final List<String> breadcrumbs;

  const TheoreticalSectionManagementScreen({
    super.key,
    required this.sectionId,
    required this.sectionName,
    required this.subjectId,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'رفع أسئلة (CSV)',
            onPressed: () {
              // Note: widget.subjectId is technically not directly available here, we need the subjectId.
              // Actually, the questions belong to a subjectId, but here we have sectionId. 
              // Wait, the model uses subjectId. Let me check the constructor of this widget.
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
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getQuestions(widget.sectionId),
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
            return _buildQuestionCard(id, data, isDark);
          },
        );
      },
    );
  }

  Widget _buildQuestionCard(String id, Map<String, dynamic> data, bool isDark) {
    final String typeStr = data['type'] == 'mcq' ? 'أتمتة' : (data['type'] == 'tf' ? 'صح/خطأ' : 'مقالي');
    final Color typeColor = data['type'] == 'mcq' ? Colors.blue : (data['type'] == 'tf' ? Colors.teal : Colors.orange);
    final questionText = data['text'] ?? '';
    final analytics = QuestionAnalytics.fromMap(data['analytics']);
    
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
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                typeStr,
                style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
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
                if (data['type'] == 'mcq' || data['type'] == 'tf') ...[
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
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('تحليلات الأداء', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaChip(Icons.people_alt_rounded, '${analytics.timesAnswered} محاولة', Colors.blueGrey),
                    _buildMetaChip(Icons.percent_rounded, 'نجاح ${(analytics.successRate * 100).toStringAsFixed(1)}%', analytics.successRate >= 0.5 || analytics.timesAnswered == 0 ? Colors.green : Colors.red),
                    _buildMetaChip(Icons.timer_outlined, 'متوسط ${analytics.avgTime.toStringAsFixed(1)} ثانية', Colors.deepOrange),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaChip(Icons.speed_rounded, _translateDifficulty(data['difficulty']), Colors.purple),
                    _buildMetaChip(Icons.psychology_rounded, _translateCognitiveLevel(data['cognitiveLevel']), Colors.indigo),
                    _buildMetaChip(Icons.timer_rounded, '${data['estimatedTime'] ?? 60} ثانية', Colors.teal),
                  ],
                ),
                if (data['explanation'] != null && data['explanation'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.primaryBlue),
                            const SizedBox(width: 6),
                            Text('الشرح', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryBlue)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(data['explanation'], style: GoogleFonts.cairo(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _translateDifficulty(String? d) {
    switch (d) {
      case 'easy': return 'سهل';
      case 'hard': return 'صعب';
      case 'medium':
      default: return 'متوسط';
    }
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
    _showQuestionDialog();
  }

  void _showEditQuestionDialog(String id, Map<String, dynamic> currentData) {
    _showQuestionDialog(id: id, currentData: currentData);
  }

  void _showQuestionDialog({String? id, Map<String, dynamic>? currentData}) {
    final bool isEdit = id != null;
    QuestionType selectedType = currentData?['type'] == 'essay' ? QuestionType.essay : (currentData?['type'] == 'tf' ? QuestionType.trueFalse : QuestionType.mcq);
    final textController = TextEditingController(text: currentData?['text']);
    final essayAnswerController = TextEditingController(text: currentData?['essayAnswer']);
    final explanationController = TextEditingController(text: currentData?['explanation']);
    final timeController = TextEditingController(text: currentData?['estimatedTime']?.toString() ?? '60');
    
    String? selectedTopicId = currentData?['topicId'];
    Difficulty selectedDifficulty = Difficulty.values.firstWhere((e) => e.name == currentData?['difficulty'], orElse: () => Difficulty.medium);
    CognitiveLevel selectedLevel = CognitiveLevel.values.firstWhere((e) => e.name == currentData?['cognitiveLevel'], orElse: () => CognitiveLevel.understanding);
    
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
                  RadioGroup<QuestionType>(
                    groupValue: selectedType,
                    onChanged: (v) {
                      setDialogState(() {
                        selectedType = v!;
                        if (selectedType == QuestionType.trueFalse && (options.isEmpty || options.length != 2)) {
                          options = [
                            {'id': 'true', 'text': 'صح'},
                            {'id': 'false', 'text': 'خطأ'}
                          ];
                          correctOptionId = 'true';
                        }
                      });
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<QuestionType>(
                            title: Text('أتمتة', style: GoogleFonts.cairo(fontSize: 12)),
                            value: QuestionType.mcq,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<QuestionType>(
                            title: Text('مقالي', style: GoogleFonts.cairo(fontSize: 12)),
                            value: QuestionType.essay,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<QuestionType>(
                            title: Text('صح/خطأ', style: GoogleFonts.cairo(fontSize: 12)),
                            value: QuestionType.trueFalse,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('الموضوع (الفصل/الدرس)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection(DatabaseService.colTopics)
                        .where('subjectId', isEqualTo: widget.subjectId)
                        .orderBy('order').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      final topics = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        initialValue: selectedTopicId,
                        isExpanded: true,
                        hint: Text('اختر الموضوع', style: GoogleFonts.cairo(fontSize: 12)),
                        items: topics.map((t) {
                          final d = t.data() as Map<String, dynamic>;
                          final prefix = d['type'] == 'chapter' ? '' : (d['type'] == 'lesson' ? '  - ' : '    -- ');
                          return DropdownMenuItem(
                            value: t.id,
                            child: Text(prefix + d['name'], style: GoogleFonts.cairo(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (v) => setDialogState(() => selectedTopicId = v),
                      );
                    },
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
                    RadioGroup<String>(
                      groupValue: correctOptionId ?? '',
                      onChanged: (v) => setDialogState(() => correctOptionId = v),
                      child: Column(
                        children: options.asMap().entries.map((entry) {
                          final opt = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: opt['id']!,
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
                        }).toList(),
                      ),
                    ),
                  ] else if (selectedType == QuestionType.essay) ...[
                    TextField(
                      controller: essayAnswerController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'الإجابة النموذجية (اختياري)',
                        labelStyle: GoogleFonts.cairo(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ] else ...[
                    // True/False
                    Text('الإجابة الصحيحة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                    RadioGroup<String>(
                      groupValue: correctOptionId ?? 'true',
                      onChanged: (v) => setDialogState(() => correctOptionId = v),
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('صح', style: GoogleFonts.cairo()),
                              value: 'true',
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('خطأ', style: GoogleFonts.cairo()),
                              value: 'false',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text('بيانات متقدمة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlue)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: explanationController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'شرح الإجابة (يظهر للطالب بعد الحل)',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Difficulty>(
                          initialValue: selectedDifficulty,
                          decoration: InputDecoration(labelText: 'الصعوبة', labelStyle: GoogleFonts.cairo()),
                          items: Difficulty.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: GoogleFonts.cairo()))).toList(),
                          onChanged: (v) => setDialogState(() => selectedDifficulty = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<CognitiveLevel>(
                          initialValue: selectedLevel,
                          decoration: InputDecoration(labelText: 'المستوى المعرفي', labelStyle: GoogleFonts.cairo()),
                          items: CognitiveLevel.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: GoogleFonts.cairo()))).toList(),
                          onChanged: (v) => setDialogState(() => selectedLevel = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: timeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'الوقت المقدر (ثانية)',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
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
                  'type': selectedType == QuestionType.mcq ? 'mcq' : (selectedType == QuestionType.trueFalse ? 'tf' : 'essay'),
                  'topicId': selectedTopicId,
                  'explanation': explanationController.text.trim(),
                  'difficulty': selectedDifficulty.name,
                  'cognitiveLevel': selectedLevel.name,
                  'estimatedTime': int.tryParse(timeController.text) ?? 60,
                  'topicIds': selectedTopicId != null ? [selectedTopicId!] : [],
                };

                if (selectedType == QuestionType.mcq || selectedType == QuestionType.trueFalse) {
                  questionData['options'] = options;
                  questionData['correctOptionId'] = correctOptionId;
                } else {
                  questionData['essayAnswer'] = essayAnswerController.text.trim();
                }

                try {
                  if (isEdit) {
                    await _dbService.updateDoc(DatabaseService.colQuestions, id, questionData);
                  } else {
                    await _dbService.addQuestion(widget.sectionId, questionData);
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    _showStatusSnackBar(isEdit ? 'تم تحديث السؤال بنجاح' : 'تم إضافة السؤال بنجاح', isError: false);
                  }
                } catch (e) {
                  if (mounted) _showStatusSnackBar('حدث خطأ: $e', isError: true);
                }
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
              try {
                await _dbService.deleteDoc(DatabaseService.colQuestions, id);
                if (mounted) {
                  Navigator.pop(context);
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
}
