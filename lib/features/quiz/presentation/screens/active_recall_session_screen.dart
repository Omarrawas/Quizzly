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
  bool _isFlashcardMode = false;

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final q = _queue[_currentIndex];
    final progress = (_currentIndex + 1) / _queue.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isFlashcardMode ? 'البطاقات الذكية' : 'وضع الحفظ (Active Recall)',
          style: GoogleFonts.cairo(
            fontSize: 16, 
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.white : AppColors.textPrimary
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
            ),
            child: Row(
              children: [
                _buildModeTab(Icons.style_rounded, true, isDark),
                _buildModeTab(Icons.list_alt_rounded, false, isDark),
              ],
            ),
          ),
        ],
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
                backgroundColor: isDark ? Colors.white10 : Colors.white,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'بطاقة ${_currentIndex + 1} من ${_queue.length}',
            style: GoogleFonts.cairo(
              fontSize: 12, 
              color: isDark ? Colors.white38 : AppColors.textSecondary, 
              fontWeight: FontWeight.bold
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _isFlashcardMode ? _buildFlashcard(q, isDark) : _buildActiveRecallCard(q, isDark),
            ),
          ),
          _buildFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildModeTab(IconData icon, bool isFlash, bool isDark) {
    final isSelected = _isFlashcardMode == isFlash;
    return GestureDetector(
      onTap: () => setState(() {
        _isFlashcardMode = isFlash;
        _showAnswer = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isSelected ? Colors.white : (isDark ? Colors.white38 : Colors.grey), size: 18),
      ),
    );
  }

  Widget _buildActiveRecallCard(QuizQuestion q, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), 
            blurRadius: 20
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            q.text,
            style: GoogleFonts.cairo(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              height: 1.6,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          if (_showAnswer) ...[
            const SizedBox(height: 24),
            Divider(color: isDark ? Colors.white10 : null),
            const SizedBox(height: 24),
            _buildAnswerSection(q, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildFlashcard(QuizQuestion q, bool isDark) {
    return GestureDetector(
      onTap: _toggleAnswer,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          final rotate = Tween(begin: 3.14, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            child: child,
            builder: (context, widgetChild) {
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(rotate.value);
                
              return Transform(
                transform: transform,
                alignment: Alignment.center,
                child: widgetChild,
              );
            },
          );
        },
        child: _showAnswer ? _buildFlashcardBack(q, isDark) : _buildFlashcardFront(q.text, isDark),
      ),
    );
  }

  Widget _buildFlashcardFront(String text, bool isDark) {
    return Container(
      key: const ValueKey(true),
      width: double.infinity,
      height: 350,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), 
            blurRadius: 20
          )
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.cairo(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            height: 1.6,
            color: isDark ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildFlashcardBack(QuizQuestion q, bool isDark) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(3.14),
      child: Container(
        key: const ValueKey(false),
        width: double.infinity,
        height: 350,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFF16A34A), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), 
              blurRadius: 20
            )
          ],
        ),
        child: Center(
          child: SingleChildScrollView(
            child: _buildAnswerSection(q, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerSection(QuizQuestion q, bool isDark) {
    final correctOption = (q.options ?? []).isEmpty
        ? null
        : (q.options ?? []).cast<QuizOption?>().firstWhere(
              (o) => o != null && q.correctOptionIds.contains(o.id),
              orElse: () => null,
            );
    return Column(
      children: [
        if (!_isFlashcardMode)
          Text(
            'الجواب الصحيح:',
            style: GoogleFonts.cairo(
              fontSize: 14, 
              color: isDark ? Colors.white38 : AppColors.textSecondary
            ),
          ),
        if (_isFlashcardMode)
          Icon(
            Icons.check_circle_rounded, 
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A), 
            size: 40
          ),
        const SizedBox(height: 12),
        Text(
          correctOption?.text ?? 'غير محدد',
          style: GoogleFonts.cairo(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF166534)
          ),
          textAlign: TextAlign.center,
        ),
        if (q.explanation != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isFlashcardMode 
                ? (isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.5)) 
                : (isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              q.explanation!,
              style: GoogleFonts.cairo(
                fontSize: 13, 
                color: isDark ? Colors.white70 : AppColors.textPrimary
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: isDark ? const Border(top: BorderSide(color: Colors.white10)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1), 
            blurRadius: 20
          )
        ],
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
                child: Text(_isFlashcardMode ? 'اقلب البطاقة' : 'عرض الإجابة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'هل استطعت تذكر الإجابة؟',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold, 
                    color: isDark ? Colors.white : AppColors.textPrimary
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _RatingButton(
                        label: 'صعب جداً',
                        color: Colors.redAccent,
                        isDark: isDark,
                        onTap: () => _recordPerformance(0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RatingButton(
                        label: 'بصعوبة',
                        color: Colors.orangeAccent,
                        isDark: isDark,
                        onTap: () => _recordPerformance(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RatingButton(
                        label: 'سهل',
                        color: Colors.greenAccent,
                        isDark: isDark,
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
  final bool isDark;
  final VoidCallback onTap;

  const _RatingButton({
    required this.label, 
    required this.color, 
    required this.isDark,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: isDark ? 0.2 : 0.1),
        foregroundColor: isDark ? color : color.withValues(alpha: 0.9),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: isDark ? 0.4 : 0.3)),
        ),
      ),
      child: Text(
        label, 
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold, 
          fontSize: 12
        )
      ),
    );
  }
}

