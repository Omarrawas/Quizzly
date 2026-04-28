import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class ExamFlashcardsScreen extends StatefulWidget {
  final ExamConfig config;
  final List<QuizQuestion> questions;

  const ExamFlashcardsScreen({
    super.key,
    required this.config,
    required this.questions,
  });

  @override
  State<ExamFlashcardsScreen> createState() => _ExamFlashcardsScreenState();
}

class _ExamFlashcardsScreenState extends State<ExamFlashcardsScreen> {
  int _currentIndex = 0;
  bool _isFlipped = false;

  void _flipCard() {
    setState(() => _isFlipped = !_isFlipped);
  }

  void _nextCard() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_currentIndex];
    final correctOption = q.options?.firstWhere((o) => q.correctOptionIds.contains(o.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'بطاقات ذكية - ${widget.config.title}',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            Text(
              'البطاقة ${_currentIndex + 1} من ${widget.questions.length}',
              style: GoogleFonts.cairo(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GestureDetector(
                onTap: _flipCard,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    final rotate = Tween(begin: 3.14, end: 0.0).animate(animation);
                    return AnimatedBuilder(
                      animation: rotate,
                      builder: (context, child) {
                        return Transform(
                          transform: Matrix4.rotationY(rotate.value),
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                    );
                  },
                  child: _isFlipped ? _buildBack(correctOption, q.explanation) : _buildFront(q.text),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _flipCard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.primaryBlue)),
                  ),
                  child: Text('اقلب البطاقة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _nextCard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _currentIndex == widget.questions.length - 1 ? 'إنهاء' : 'التالي',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFront(String text) {
    return Container(
      key: const ValueKey(true),
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, height: 1.6),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBack(QuizOption? correctOption, String? explanation) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(3.14),
      child: Container(
        key: const ValueKey(false),
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF16A34A), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
            const SizedBox(height: 24),
            Text(
              'الإجابة الصحيحة:',
              style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              correctOption?.text ?? 'غير محددة',
              style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
              textAlign: TextAlign.center,
            ),
            if (explanation != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                explanation,
                style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF166534)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
