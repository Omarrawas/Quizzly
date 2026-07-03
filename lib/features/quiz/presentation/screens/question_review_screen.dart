import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/ai_grading_service.dart';
import 'package:quizzly/features/quiz/presentation/widgets/interactive_explanation.dart';
import 'package:quizzly/core/widgets/zoomable_image.dart';

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
        Text('إجابتك:', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            studentAnswer.isEmpty ? '(لم يتم العثور على إجابة)' : studentAnswer,
            style: GoogleFonts.tajawal(fontSize: 14),
          ),
        ),
        const SizedBox(height: 16),
        Text('الإجابة النموذجية:', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
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
        if (isLoading)
          _AIGradingLoadingWidget(isDark: isDark)
        else if (aiResult == null)
          ElevatedButton.icon(
            onPressed: () => _handleAIGrade(index, q, studentAnswer),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text('صحح لي بواسطة الذكاء الاصطناعي', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6E56FF), // Dark Fintech Primary Color #6E56FF
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
        color: const Color(0xFF6E56FF).withValues(alpha: 0.1), // Dark Fintech Primary Color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2E36)), // Fintech 1px border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF6E56FF), size: 18),
              const SizedBox(width: 8),
              Text('تقييم الذكاء الاصطناعي:', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: const Color(0xFF6E56FF))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF6E56FF), borderRadius: BorderRadius.circular(8)),
                child: Text('${result.score}/10', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(result.feedback, style: GoogleFonts.tajawal(fontSize: 13, height: 1.5)),
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
          ZoomableImage(
            imageUrl: question.explanationImageUrl!,
            fit: BoxFit.contain,
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

class _AIGradingLoadingWidget extends StatefulWidget {
  final bool isDark;
  const _AIGradingLoadingWidget({required this.isDark});

  @override
  State<_AIGradingLoadingWidget> createState() => _AIGradingLoadingWidgetState();
}

class _AIGradingLoadingWidgetState extends State<_AIGradingLoadingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late DateTime _startTime;
  int _elapsedSeconds = 0;
  Timer? _timer;

  final List<String> _loadingMessages = [
    'جاري الاتصال بخادم الذكاء الاصطناعي...',
    'جاري فحص السؤال ومطابقته بالإجابة النموذجية...',
    'الذكاء الاصطناعي يحلل نقاط القوة والضعف في إجابتك...',
    'جاري تقييم الدرجة وكتابة تعليق تفصيلي...',
    'أوشكنا على الانتهاء، جاري استلام التقييم...',
  ];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(_startTime).inSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _getMessage() {
    if (_elapsedSeconds < 2) return _loadingMessages[0];
    if (_elapsedSeconds < 5) return _loadingMessages[1];
    if (_elapsedSeconds < 8) return _loadingMessages[2];
    if (_elapsedSeconds < 12) return _loadingMessages[3];
    return _loadingMessages[4];
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? const Color(0xFF222329) : Colors.grey.shade50;
    final primaryColor = const Color(0xFF6E56FF); // Dark Fintech primary color

    return FadeTransition(
      opacity: _pulseController.drive(Tween<double>(begin: 0.6, end: 1.0)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2D2E36)), // Fintech 1px border
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getMessage(),
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: widget.isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الوقت المنقضي: $_elapsedSeconds ثانية',
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      color: widget.isDark ? Colors.white38 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
