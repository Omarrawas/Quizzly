import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/spaced_repetition_service.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/gamification/domain/services/gamification_service.dart';
import 'package:quizzly/features/gamification/domain/services/subject_league_service.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';

class ActiveRecallSessionScreen extends StatefulWidget {
  final ExamConfig config;
  final List<QuizQuestion> questions;

  const ActiveRecallSessionScreen({
    super.key,
    required this.config,
    required this.questions,
  });

  @override
  State<ActiveRecallSessionScreen> createState() =>
      _ActiveRecallSessionScreenState();
}

class _ActiveRecallSessionScreenState extends State<ActiveRecallSessionScreen>
    with SingleTickerProviderStateMixin {
  final SpacedRepetitionService _srs = SpacedRepetitionService();
  late List<QuizQuestion> _queue;
  int _currentIndex = 0;
  bool _showAnswer = false;

  late AnimationController _animationController;
  Animation<Offset>? _offsetAnimation;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  final double _swipeThreshold = 100.0;
  bool _thresholdCrossed = false;

  @override
  void initState() {
    super.initState();
    _queue = List.from(widget.questions);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animationController.addListener(() {
      if (_offsetAnimation != null) {
        setState(() {
          _dragOffset = _offsetAnimation!.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_showAnswer) return;
    _animationController.stop();
    setState(() {
      _isDragging = true;
      _thresholdCrossed = false;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_showAnswer) return;
    setState(() {
      _dragOffset += details.delta;
    });

    final bool currentCrossed = _isThresholdCrossed();
    if (currentCrossed && !_thresholdCrossed) {
      HapticFeedback.selectionClick();
      _thresholdCrossed = true;
    } else if (!currentCrossed && _thresholdCrossed) {
      _thresholdCrossed = false;
    }
  }

  bool _isThresholdCrossed() {
    if (_dragOffset.dx.abs() > _dragOffset.dy.abs()) {
      return _dragOffset.dx.abs() > _swipeThreshold;
    } else {
      return _dragOffset.dy < -_swipeThreshold;
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_showAnswer) return;
    setState(() {
      _isDragging = false;
    });

    if (_dragOffset.dx.abs() > _dragOffset.dy.abs()) {
      if (_dragOffset.dx > _swipeThreshold) {
        _swipeOut(const Offset(600, 0), 5);
      } else if (_dragOffset.dx < -_swipeThreshold) {
        _swipeOut(const Offset(-600, 0), 0);
      } else {
        _snapBack();
      }
    } else {
      if (_dragOffset.dy < -_swipeThreshold) {
        _swipeOut(const Offset(0, -800), 3);
      } else {
        _snapBack();
      }
    }
  }

  void _snapBack() {
    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward(from: 0.0);
  }

  void _swipeOut(Offset targetOffset, int quality) {
    HapticFeedback.mediumImpact();
    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
        });
        _recordPerformance(quality);
      }
    });
  }

  void _onRatingButtonPressed(int quality) {
    Offset targetOffset;
    if (quality == 5) {
      targetOffset = const Offset(600, 0);
    } else if (quality == 3) {
      targetOffset = const Offset(0, -800);
    } else {
      targetOffset = const Offset(-600, 0);
    }
    _swipeOut(targetOffset, quality);
  }

  void _toggleAnswer() {
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  Future<void> _recordPerformance(int quality) async {
    final auth = context.read<AuthService>();
    final user = auth.user;
    final userId = user?.uid;
    final userName = user?.displayName ?? user?.email?.split('@').first ?? 'طالب';
    final userAvatar = user?.photoURL;

    final q = _queue[_currentIndex];
    final qId = q.id;

    if (userId != null && qId != null) {
      try {
        await _srs.updateMastery(
          userId: userId,
          questionId: qId,
          subjectId: widget.config.subjectId,
          quality: quality,
        );
        
        final int xpGained = quality >= 5 ? 5 : (quality >= 3 ? 3 : 1);
        final gamification = GamificationService();
        final leagues = SubjectLeagueService();

        gamification.addXp(userId, xpGained);
        leagues.addSubjectXp(
          userId: userId,
          subjectId: widget.config.subjectId,
          xpGained: xpGained,
          userName: userName,
          userAvatar: userAvatar,
        );
      } catch (e) {
        debugPrint('Error updating mastery in active recall: $e');
      }
    } else {
      debugPrint(
        'Warning: userId or question ID is null. userId: $userId, questionId: $qId',
      );
    }

    if (quality < 3) {
      final insertAt = (_currentIndex + 4).clamp(0, _queue.length);
      setState(() {
        _queue.insert(insertAt, q);
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
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'البطاقات الذكية',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
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
                backgroundColor: isDark ? Colors.white10 : Colors.white,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'بطاقة ${_currentIndex + 1} من ${_queue.length}',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: isDark ? Colors.white38 : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildFlashcard(q, isDark),
            ),
          ),
          _buildFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildFlashcard(QuizQuestion q, bool isDark) {
    double tiltRotation = (_dragOffset.dx / 600).clamp(-0.15, 0.15);

    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTap: _isDragging ? null : _toggleAnswer,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: _dragOffset,
            child: Transform.rotate(
              angle: tiltRotation,
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
                child: _showAnswer
                    ? _buildFlashcardBack(q, isDark)
                    : _buildFlashcardFront(q.text, isDark),
              ),
            ),
          ),
          if (_showAnswer) _buildSwipeIndicatorOverlay(),
        ],
      ),
    );
  }

  Widget _buildSwipeIndicatorOverlay() {
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;
    const startThreshold = 15.0;
    
    String label = '';
    Color color = Colors.transparent;
    double opacity = 0.0;
    IconData icon = Icons.check;

    if (dx.abs() > dy.abs()) {
      if (dx > startThreshold) {
        label = 'سهل';
        color = const Color(0xFF10B981);
        opacity = ((dx - startThreshold) / (_swipeThreshold - startThreshold)).clamp(0.0, 1.0);
        icon = Icons.sentiment_very_satisfied_rounded;
      } else if (dx < -startThreshold) {
        label = 'صعب';
        color = const Color(0xFFEF4444);
        opacity = ((-dx - startThreshold) / (_swipeThreshold - startThreshold)).clamp(0.0, 1.0);
        icon = Icons.sentiment_very_dissatisfied_rounded;
      }
    } else {
      if (dy < -startThreshold) {
        label = 'متوسط';
        color = const Color(0xFFFBBF24);
        opacity = ((-dy - startThreshold) / (_swipeThreshold - startThreshold)).clamp(0.0, 1.0);
        icon = Icons.sentiment_satisfied_rounded;
      }
    }

    if (opacity == 0.0) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: opacity,
          duration: Duration.zero,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.8), width: 3),
              color: color.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
            blurRadius: 20,
          ),
        ],
      ),
      child: Center(
        child: TexViewWidget(
          text: text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
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
          border: Border.all(
            color: isDark ? const Color(0xFF059669) : const Color(0xFF16A34A),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 20,
            ),
          ],
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(3.14),
              child: _buildAnswerSection(q, isDark),
            ),
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
    final hasEssay = q.type == QuestionType.essay || (q.essayAnswer != null && q.essayAnswer!.isNotEmpty);
    return Column(
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
          size: 40,
        ),
        const SizedBox(height: 12),
        TexViewWidget(
          text: hasEssay ? (q.essayAnswer ?? 'غير محدد') : (correctOption?.text ?? 'غير محدد'),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF166534),
        ),
        if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TexViewWidget(
              text: q.explanation!,
              fontSize: 13,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
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
        border: isDark
            ? const Border(top: BorderSide(color: Colors.white10))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 20,
          ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'اقلب البطاقة',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'هل استطعت تذكر الإجابة؟',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _RatingButton(
                        label: 'سهل',
                        color: Colors.greenAccent,
                        isDark: isDark,
                        onTap: () => _onRatingButtonPressed(5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RatingButton(
                        label: 'متوسط',
                        color: Colors.orangeAccent,
                        isDark: isDark,
                        onTap: () => _onRatingButtonPressed(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RatingButton(
                        label: 'صعب',
                        color: Colors.redAccent,
                        isDark: isDark,
                        onTap: () => _onRatingButtonPressed(0),
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
    required this.onTap,
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
        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
