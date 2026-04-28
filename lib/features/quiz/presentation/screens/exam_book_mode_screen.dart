import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';

class ExamBookModeScreen extends StatefulWidget {
  final ExamConfig config;
  final List<QuizQuestion> questions;

  const ExamBookModeScreen({
    super.key,
    required this.config,
    required this.questions,
  });

  @override
  State<ExamBookModeScreen> createState() => _ExamBookModeScreenState();
}

class _ExamBookModeScreenState extends State<ExamBookModeScreen> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  bool _isTimerRunning = true;
  
  // Dummy counts for book mode (since it's just browsing)
  // But we show them for UI completeness as requested
  final int _correctCount = 0;
  final int _wrongCount = 0;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      if (_isTimerRunning) {
        _stopwatch.stop();
      } else {
        _stopwatch.start();
      }
      _isTimerRunning = !_isTimerRunning;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mock exam data for the header
    final mockExam = QuizExam(
      title: widget.config.title,
      classification: 'الدورات الوزارية',
      lastUpdated: '21/02/2024',
      totalQuestions: widget.questions.length,
      questions: widget.questions,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.config.title,
          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
          ),
        ],
        centerTitle: false,
      ),
      body: Column(
        children: [
          QuizHud(
            current: widget.questions.length,
            total: widget.questions.length,
            correctCount: _correctCount,
            wrongCount: _wrongCount,
            elapsed: _stopwatch.elapsed,
            isTimerRunning: _isTimerRunning,
            onToggleTimer: _toggleTimer,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                QuizExamHeader(exam: mockExam),
                const SizedBox(height: 8),
                ...widget.questions.map((q) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        QuestionCard(
                          question: q,
                          selectedOptionId: null,
                          answerState: AnswerState.unanswered,
                          showCorrect: true,
                          onOptionSelected: (_) {},
                        ),
                        if (q.explanation != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFF16A34A)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    q.explanation!,
                                    style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF166534)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
