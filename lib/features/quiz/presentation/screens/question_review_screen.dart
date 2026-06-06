import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/ai_grading_service.dart';
import 'package:quizzly/features/quiz/presentation/widgets/interactive_explanation.dart';

class QuestionReviewScreen extends StatefulWidget {
  final List<QuizQuestion> questions;
  final Map<int, dynamic> userAnswers;

  const QuestionReviewScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
  });

  @override
  State<QuestionReviewScreen> createState() => _QuestionReviewScreenState();
}

class _QuestionReviewScreenState extends State<QuestionReviewScreen> {
  final AIGradingService _aiService = AIGradingService();
  final Map<int, AIGradingResult?> _aiResults = {};
  final Set<int> _loadingIndices = {};

  Future<void> _handleAIGrade(int index, QuizQuestion q, String studentAnswer) async {
    setState(() {
      _loadingIndices.add(index);
    });

    try {
      final result = await _aiService.gradeEssayAnswer(
        question: q.text,
        studentAnswer: studentAnswer,
        modelAnswer: q.essayAnswer ?? q.explanation ?? 'لا توجد إجابة نموذجية',
        explanation: q.explanation,
      );

      setState(() {
        _aiResults[index] = result;
      });
    } finally {
      setState(() {
        _loadingIndices.remove(index);
      });
    }
  }

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
        itemCount: widget.questions.length,
        itemBuilder: (context, index) {
          final question = widget.questions[index];
          final userAns = widget.userAnswers[index];
          
          bool isCorrect = false;
          bool isEssay = question.type == QuestionType.essay;

          if (!isEssay) {
            if (userAns is Set<String>) {
              isCorrect = userAns.length == question.correctOptionIds.length &&
                  userAns.every((id) => question.correctOptionIds.contains(id));
            } else if (userAns is String && !isEssay) {
              isCorrect = question.correctOptionIds.contains(userAns);
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEssay 
                    ? Colors.blue.withValues(alpha: 0.3)
                    : (isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
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
                        color: isEssay ? Colors.blue : (isCorrect ? Colors.green : Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'سؤال ${index + 1} ${isEssay ? "(مقالي)" : ""}',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!isEssay) ...[
                      const SizedBox(width: 12),
                      Icon(
                        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isCorrect ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                TexViewWidget(
                  text: question.text,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 20),
                
                if (isEssay) _buildEssaySection(index, question, userAns as String? ?? '', isDark)
                else _buildOptionsSection(question, userAns, isCorrect, isDark),
                
                _buildExplanationSection(question, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEssaySection(int index, QuizQuestion q, String studentAnswer, bool isDark) {
    final aiResult = _aiResults[index];
    final isLoading = _loadingIndices.contains(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('إجابتك:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            studentAnswer.isEmpty ? '(لم يتم العثور على إجابة)' : studentAnswer,
            style: GoogleFonts.cairo(fontSize: 14),
          ),
        ),
        const SizedBox(height: 16),
        Text('الإجابة النموذجية:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
          ),
          child: TexViewWidget(text: q.essayAnswer ?? q.explanation ?? 'غير متوفرة', fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (aiResult == null)
          ElevatedButton.icon(
            onPressed: isLoading ? null : () => _handleAIGrade(index, q, studentAnswer),
            icon: isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(isLoading ? 'جاري التصحيح...' : 'صحح لي بواسطة الذكاء الاصطناعي'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        else
          _buildAIResultCard(aiResult, isDark),
      ],
    );
  }

  Widget _buildAIResultCard(AIGradingResult result, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 18),
              const SizedBox(width: 8),
              Text('تقييم الذكاء الاصطناعي:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFF6366F1))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(8)),
                child: Text('${result.score}/10', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(result.feedback, style: GoogleFonts.cairo(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildOptionsSection(QuizQuestion question, dynamic userAns, bool isCorrect, bool isDark) {
    return Column(
      children: (question.options ?? []).map((opt) {
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
      }).toList(),
    );
  }

  Widget _buildExplanationSection(QuizQuestion question, bool isDark) {
    if (question.explanation == null || question.explanation!.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }
}
