import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/spaced_repetition_service.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';

class ActiveRecallSessionScreen extends StatefulWidget {
  final ExamConfig config;
  final List<QuizQuestion> questions;

  const ActiveRecallSessionScreen({
    super.key,
    required this.config,
    required this.questions,
  });

  @override
  State<ActiveRecallSessionScreen> createState() => _ActiveRecallSessionScreenState();
}

class _ActiveRecallSessionScreenState extends State<ActiveRecallSessionScreen> {
  final SpacedRepetitionService _srs = SpacedRepetitionService();
  late List<QuizQuestion> _queue;
  int _currentIndex = 0;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _queue = List.from(widget.questions);
  }

  void _toggleAnswer() {
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  Future<void> _recordPerformance(int quality) async {
    final userId = context.read<AuthService>().user?.uid;
    if (userId != null) {
      final q = _queue[_currentIndex];
      await _srs.updateMastery(
        userId: userId,
        questionId: q.id!,
        subjectId: widget.config.subjectId,
        quality: quality,
      );
    }

    if (quality < 3) {
      // Smart Re-entry: Add to queue again after 3-5 positions
      final currentQ = _queue[_currentIndex];
      final insertAt = (_currentIndex + 4).clamp(0, _queue.length);
      setState(() {
        _queue.insert(insertAt, currentQ);
      });
    }

    _nextQuestion();
  }

  void _nextQuestion() {
    if (_currentIndex < _queue.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _queue[_currentIndex];
    final progress = (_currentIndex + 1) / _queue.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'وضع الحفظ (Active Recall)',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'بطاقة ${_currentIndex + 1} من ${_queue.length}',
            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Question Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                    ),
                    child: Column(
                      children: [
                        Text(
                          q.text,
                          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                        if (_showAnswer) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                          _buildAnswerSection(q),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildAnswerSection(QuizQuestion q) {
    final correctOption = q.options?.firstWhere((o) => q.correctOptionIds.contains(o.id));
    return Column(
      children: [
        Text(
          'الجواب الصحيح:',
          style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          correctOption?.text ?? 'غير محدد',
          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
          textAlign: TextAlign.center,
        ),
        if (q.explanation != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              q.explanation!,
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: !_showAnswer
          ? SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _toggleAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('عرض الإجابة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'هل استطعت تذكر الإجابة؟',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _RatingButton(
                        label: 'صعب جداً',
                        color: Colors.red,
                        onTap: () => _recordPerformance(0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RatingButton(
                        label: 'بصعوبة',
                        color: Colors.orange,
                        onTap: () => _recordPerformance(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RatingButton(
                        label: 'سهل',
                        color: Colors.green,
                        onTap: () => _recordPerformance(5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RatingButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
      child: Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
