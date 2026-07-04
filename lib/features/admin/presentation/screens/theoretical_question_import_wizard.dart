import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/admin/domain/services/pdf_parsing_service.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/presentation/widgets/question_preview_edit_dialog.dart';

class TheoreticalQuestionImportWizard extends StatefulWidget {
  final List<ExtractedQuestion> extractedQuestions;
  final String subjectId;
  final String sectionId;
  final String? lessonId;
  final String? lessonName;

  const TheoreticalQuestionImportWizard({
    super.key,
    required this.extractedQuestions,
    required this.subjectId,
    required this.sectionId,
    this.lessonId,
    this.lessonName,
  });

  @override
  State<TheoreticalQuestionImportWizard> createState() => _TheoreticalQuestionImportWizardState();
}

class _TheoreticalQuestionImportWizardState extends State<TheoreticalQuestionImportWizard> {
  late List<ExtractedQuestion> _questions;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.extractedQuestions);
  }

  Future<void> _editQuestion(int index) async {
    final result = await showDialog<ExtractedQuestion>(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuestionPreviewEditDialog(
        question: _questions[index],
        subjectId: widget.subjectId,
        sectionId: widget.sectionId,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _questions[index] = result;
      });
    }
  }

  void _deleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF222329),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2D2E36)),
          ),
          title: Text(
            'تأكيد الحذف',
            style: GoogleFonts.tajawal(
              color: const Color(0xFFFF4C6A),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Text(
            'هل أنت متأكد من استبعاد هذا السؤال من الاستيراد؟',
            style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: GoogleFonts.tajawal(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _questions.removeAt(index);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4C6A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'حذف',
                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAllQuestions() async {
    if (_questions.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final collectionRef = FirebaseFirestore.instance.collection(DatabaseService.colQuestions);

      for (var question in _questions) {
        final docRef = collectionRef.doc();

        // Manage topic assignments based on target lesson
        final List<String> finalTopicIds = List.from(question.topicIds ?? []);
        final List<String> finalTopicNames = List.from(question.topicNames ?? []);

        if (widget.lessonId != null) {
          if (!finalTopicIds.contains(widget.lessonId)) {
            finalTopicIds.add(widget.lessonId!);
          }
          if (widget.lessonName != null && !finalTopicNames.contains(widget.lessonName)) {
            finalTopicNames.add(widget.lessonName!);
          }
        }

        final primaryTopic = finalTopicIds.isNotEmpty ? finalTopicIds.first : 'global';

        final questionData = {
          'text': question.text,
          'type': question.type,
          'options': question.options.map((o) => o.toMap()).toList(),
          'correctOptionIds': question.correctOptionIds,
          'subjectId': widget.subjectId,
          'parentId': widget.sectionId,
          'difficulty': 'medium',
          'cognitiveLevel': 'understanding',
          'status': 'approved',
          'estimatedTime': 60,
          'examTags': [],
          'isRepeated': false,
          'isEnabled': true,
          'topicIds': finalTopicIds,
          'topicNames': finalTopicNames,
          'primaryTopicId': primaryTopic,
          'explanation': question.explanation ?? '',
          'analytics': {
            'timesAnswered': 0,
            'correctAnswers': 0,
            'totalTimeSpent': 0,
            'successRate': 0.0,
            'avgTime': 0.0
          },
          'createdAt': FieldValue.serverTimestamp(),
        };

        batch.set(docRef, questionData);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم استيراد ${_questions.length} سؤال بنجاح',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF7DFFA2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate successful save
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء حفظ الأسئلة: $e',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF4C6A),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF18191D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF18191D),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'مراجعة واستيراد الأسئلة',
            style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: _isSaving
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6E56FF)),
                    SizedBox(height: 16),
                    Text(
                      'جاري استيراد وحفظ الأسئلة في قاعدة البيانات...',
                      style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
                    ),
                  ],
                ),
              )
            : _questions.isEmpty
                ? Center(
                    child: Text(
                      'لم يتبق أي أسئلة للاستيراد.',
                      style: GoogleFonts.tajawal(color: Colors.white30, fontSize: 14),
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: const Color(0xFF222329),
                        child: Text(
                          'تم استخراج ${_questions.length} سؤال. يرجى مراجعتها وتعديلها أو حذف غير المناسب منها قبل الاستيراد.',
                          style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _questions.length,
                          itemBuilder: (context, index) {
                            final question = _questions[index];
                            return _buildQuestionCard(question, index);
                          },
                        ),
                      ),
                      _buildBottomActions(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildQuestionCard(ExtractedQuestion question, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF222329),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2E36), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header & Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6E56FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'سؤال ${index + 1}',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFF6E56FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 22),
                      tooltip: 'تعديل السؤال',
                      onPressed: () => _editQuestion(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4C6A), size: 22),
                      tooltip: 'حذف السؤال',
                      onPressed: () => _deleteQuestion(index),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Question Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TexViewWidget(
              text: question.text,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // Options List
          if (question.type != 'essay')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: question.options.map((opt) {
                  final isCorrect = question.correctOptionIds.contains(opt.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCorrect ? const Color(0xFF7DFFA2).withValues(alpha: 0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCorrect ? const Color(0xFF7DFFA2).withValues(alpha: 0.3) : const Color(0xFF2D2E36),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: isCorrect ? const Color(0xFF7DFFA2) : Colors.white30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TexViewWidget(
                            text: '${opt.id}) ${opt.text}',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Explanation
          if (question.explanation != null && question.explanation!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Color(0xFF2D2E36), height: 24),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'التفسير والشرح:',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFF7DFFA2),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TexViewWidget(
                    text: question.explanation!,
                    fontSize: 12,
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF222329),
        border: Border(top: BorderSide(color: Color(0xFF2D2E36), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF2D2E36)),
                ),
              ),
              child: Text(
                'إلغاء الاستيراد',
                style: GoogleFonts.tajawal(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _saveAllQuestions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E56FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'استيراد الأسئلة (${_questions.length})',
                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
