import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quiz/data/models/quiz_models.dart';
import '../../../quiz/presentation/screens/exam_book_mode_screen.dart';

class SubjectSearchScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const SubjectSearchScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SubjectSearchScreen> createState() => _SubjectSearchScreenState();
}

class _SubjectSearchScreenState extends State<SubjectSearchScreen> {
  bool _isLoading = true;
  List<QuizQuestion> _allQuestions = [];

  @override
  void initState() {
    super.initState();
    _fetchAllQuestions();
  }

  Future<void> _fetchAllQuestions() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('questions')
          .where('subjectId', isEqualTo: widget.subjectId)
          .get();

      if (snap.docs.isNotEmpty) {
        _allQuestions = snap.docs
            .map((doc) => QuizQuestion.fromMap(
                Map<String, dynamic>.from(doc.data()), doc.id))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching questions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'البحث في الأسئلة',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final config = ExamConfig(
      id: '${widget.subjectId}_global_search',
      title: 'بحث شامل - ${widget.subjectName}',
      type: ExamType.bank,
      durationSeconds: 0,
      totalQuestions: _allQuestions.length,
      passingScore: 50,
      subjectId: widget.subjectId,
      sectionId: '',
      category: 'بحث شامل',
      staticQuestionIds: _allQuestions.map((q) => q.id ?? '').toList(),
      isFree: true,
      lastUpdated: DateTime.now(),
      createdAt: DateTime.now(),
    );

    return ExamBookModeScreen(
      config: config,
      questions: _allQuestions,
      isSubExam: true,
      isGlobalSearch: true,
    );
  }
}
