import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';

class ExamBookModeScreen extends StatelessWidget {
  final ExamConfig config;
  final List<QuizQuestion> questions;

  const ExamBookModeScreen({
    super.key,
    required this.config,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          config.title,
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final q = questions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'سؤال ${index + 1}',
                        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                QuestionCard(
                  question: q,
                  selectedOptionId: null, // No selection in browse mode
                  answerState: AnswerState.unanswered,
                  showCorrect: true, // Always show correct answer in book mode
                  onOptionSelected: (_) {}, // Disable interaction
                ),
                if (q.explanation != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
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
        },
      ),
    );
  }
}
