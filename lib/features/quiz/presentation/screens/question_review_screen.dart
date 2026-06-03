import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/interactive_explanation.dart';

class QuestionReviewScreen extends StatelessWidget {
  final List<QuizQuestion> questions;
  final Map<int, dynamic> userAnswers;

  const QuestionReviewScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('مراجعة الإجابات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final question = questions[index];
          final userAns = userAnswers[index];
          
          bool isCorrect = false;
          if (userAns is Set<String>) {
            isCorrect = userAns.length == question.correctOptionIds.length &&
                userAns.every((id) => question.correctOptionIds.contains(id));
          } else if (userAns is String) {
            isCorrect = question.correctOptionIds.contains(userAns);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'سؤال ${index + 1}',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isCorrect ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TexViewWidget(
                  text: question.text,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 20),
                // Options
                ... (question.options ?? []).map((opt) {
                  bool isUserChoice = false;
                  if (userAns is Set<String>) {
                    isUserChoice = userAns.contains(opt.id);
                  } else if (userAns is String) {
                    isUserChoice = userAns == opt.id;
                  }
                  
                  final isCorrectAnswer = question.correctOptionIds.contains(opt.id);
                  
                  Color bgColor = Colors.transparent;
                  Color borderColor = isDark ? Colors.white10 : AppColors.borderLight;
                  if (isCorrectAnswer) {
                    bgColor = Colors.green.withValues(alpha: 0.1);
                    borderColor = Colors.green;
                  } else if (isUserChoice && !isCorrect) {
                    bgColor = Colors.red.withValues(alpha: 0.1);
                    borderColor = Colors.red;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TexViewWidget(
                            text: opt.text,
                            fontSize: 13,
                            color: isCorrectAnswer ? Colors.green : (isUserChoice ? Colors.red : null),
                            fontWeight: (isUserChoice || isCorrectAnswer) ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isCorrectAnswer) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                        if (isUserChoice && !isCorrect) const Icon(Icons.cancel_rounded, color: Colors.red, size: 18),
                      ],
                    ),
                  );
                }),
                
                if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text('الشرح التوضيحي:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TexViewWidget(
                    text: question.explanation!,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  if (question.explanationImageUrl != null && question.explanationImageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: question.explanationImageUrl!,
                        placeholder: (context, url) => const SizedBox(
                          height: 50,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => const SizedBox(),
                      ),
                    ),
                  ],
                  if (question.explanationVideoUrl != null && question.explanationVideoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    QuickExplanationVideo(videoUrl: question.explanationVideoUrl!),
                  ],
                  if (question.explanationAudioUrl != null && question.explanationAudioUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AudioExplanationPlayer(audioUrl: question.explanationAudioUrl!),
                  ],
                  if (question.explanationPdfUrl != null && question.explanationPdfUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    PdfExplanationViewer(pdfUrl: question.explanationPdfUrl!),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
