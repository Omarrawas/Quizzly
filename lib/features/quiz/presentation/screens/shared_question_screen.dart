import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/screens/question_review_screen.dart';

class SharedQuestionScreen extends StatefulWidget {
  final String questionId;
  final String? subjectId;

  const SharedQuestionScreen({
    super.key,
    required this.questionId,
    this.subjectId,
  });

  @override
  State<SharedQuestionScreen> createState() => _SharedQuestionScreenState();
}

class _SharedQuestionScreenState extends State<SharedQuestionScreen> {
  bool _isLoading = true;
  QuizQuestion? _question;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchQuestion();
  }

  Future<void> _fetchQuestion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('questions')
          .doc(widget.questionId)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'السؤال غير موجود أو تم حذفه';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _question = QuizQuestion.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching shared question: $e');
      setState(() {
        _error = 'حدث خطأ أثناء تحميل السؤال. تأكد من اتصالك بالإنترنت.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _question == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error ?? 'فشل تحميل السؤال',
                style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('العودة'),
              ),
            ],
          ),
        ),
      );
    }

    return QuestionReviewScreen(
      questions: [_question!],
      userAnswers: const {}, 
    );
  }
}
