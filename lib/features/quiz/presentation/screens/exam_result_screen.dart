import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/features/quiz/presentation/screens/question_review_screen.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class ExamResultScreen extends StatelessWidget {
  final ExamConfig config;
  final double score;
  final int correctCount;
  final int totalCount;
  final int timeSpentSeconds;
  final List<QuizQuestion> questions;
  final Map<int, String> userAnswers;

  const ExamResultScreen({
    super.key,
    required this.config,
    required this.score,
    required this.correctCount,
    required this.totalCount,
    required this.timeSpentSeconds,
    required this.questions,
    required this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final passed = score >= config.passingScore;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(passed),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScoreCard(passed),
                  const SizedBox(height: 24),
                  _buildStatsRow(),
                  const SizedBox(height: 32),
                  _buildTopicAnalysis(),
                  const SizedBox(height: 40),
                  _buildActions(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool passed) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          passed ? 'لقد اجتزت الاختبار! 🎉' : 'حاول مرة أخرى 📚',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        background: Center(
          child: Icon(
            passed ? Icons.emoji_events_rounded : Icons.sentiment_very_dissatisfied_rounded,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ),
      automaticallyImplyLeading: false,
    );
  }

  Widget _buildScoreCard(bool passed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15)],
      ),
      child: Column(
        children: [
          Text(
            'درجتك النهائية',
            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '${score.round()}%',
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            passed ? 'أداء ممتاز، استمر في التقدم!' : 'لا تقلق، الفشل هو أول خطوة للنجاح.',
            style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatTile('الأسئلة الصحيحة', '$correctCount / $totalCount', Icons.check_circle_outline_rounded, Colors.green),
        const SizedBox(width: 12),
        _buildStatTile('الوقت المستغرق', _formatDuration(timeSpentSeconds), Icons.timer_outlined, Colors.blue),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicAnalysis() {
    // Basic analysis: which topics had wrong answers
    Map<String, List<bool>> topicPerformance = {};
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final isCorrect = q.correctOptionIds.contains(userAnswers[i]);
      for (var tid in (q.topicIds ?? [])) {
        topicPerformance.putIfAbsent(tid, () => []).add(isCorrect);
      }
    }

    if (topicPerformance.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('تحليل المواضيع', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...topicPerformance.entries.map((entry) {
          final corrects = entry.value.where((v) => v).length;
          final total = entry.value.length;
          final pct = corrects / total;
          
          final tid = entry.key;
          final topicName = questions.firstWhere(
            (q) => (q.topicIds ?? []).contains(tid),
            orElse: () => questions.first,
          ).topicNames?.first ?? 'موضوع #$tid';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    topicName,
                    style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '$corrects / $total',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: pct < 0.5 ? Colors.red : Colors.green),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('العودة للمركز', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuestionReviewScreen(
                    questions: questions,
                    userAnswers: userAnswers,
                  ),
                ),
              );
            },
            child: Text('مراجعة الإجابات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$mد $sث';
  }
}
