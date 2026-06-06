import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/exam_service.dart';
import 'package:quizzly/features/quiz/domain/services/spaced_repetition_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_result_screen.dart';
import 'package:quizzly/features/gamification/domain/services/gamification_service.dart';
import 'package:quizzly/features/gamification/domain/services/subject_league_service.dart';

class ExamSessionScreen extends StatefulWidget {
  final ExamConfig config;
  final List<QuizQuestion> questions;
  final bool initialSpeedMode;

  const ExamSessionScreen({
    super.key,
    required this.config,
    required this.questions,
    this.initialSpeedMode = false,
  });

  @override
  State<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<ExamSessionScreen> {
  final ExamService _examService = ExamService();
  final SpacedRepetitionService _srsService = SpacedRepetitionService();
  int _currentIndex = 0;
  final Map<int, Set<String>> _userAnswers = {}; // index -> Set of optionIds for MCQ/Checkbox
  final Map<int, String> _essayAnswers = {}; // index -> String for Essay

  late int _timeLeft; // Total time or Per-question time
  bool _isSpeedMode = false;
  Timer? _timer;
  late List<QuizQuestion> _sessionQuestions;
  final Set<int> _processedIndices = {};
  bool _hasNoTimer = false; // Flag for exams with 0 duration (no time limit)

  @override
  void initState() {
    super.initState();
    _isSpeedMode = widget.initialSpeedMode;
    _hasNoTimer = widget.config.durationSeconds <= 0;
    _timeLeft = _isSpeedMode ? 10 : widget.config.durationSeconds;
    if (_timeLeft <= 0 && !_isSpeedMode) {
      // For exams with no timer (durationSeconds = 0 / bank mode),
      // set a large dummy value so timer never expires
      _timeLeft = 999999;
      _hasNoTimer = true;
    }
    _sessionQuestions = List.from(widget.questions);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_hasNoTimer) return; // Don't count down for no-timer exams
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        if (_isSpeedMode) {
          _handleNext(); // Auto move to next in speed mode
        } else {
          _submitExam(auto: true);
        }
      }
    });
  }

  void _resetQuestionTimer() {
    if (_isSpeedMode) {
      setState(() {
        _timeLeft = 10;
      });
      _startTimer();
    }
  }

  String _formatTime(int seconds) {
    if (_hasNoTimer) return '--:--';
    if (_isSpeedMode) return seconds.toString();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _selectOption(String optionId) {
    if (_processedIndices.contains(_currentIndex)) return;
    
    final q = _sessionQuestions[_currentIndex];

    setState(() {
      final currentSet = _userAnswers[_currentIndex] ?? <String>{};
      
      if (q.type == QuestionType.checkbox) {
        // Toggle
        final newSet = Set<String>.from(currentSet);
        if (newSet.contains(optionId)) {
          newSet.remove(optionId);
        } else {
          newSet.add(optionId);
        }
        _userAnswers[_currentIndex] = newSet;
      } else {
        // Single choice
        _userAnswers[_currentIndex] = {optionId};
      }
    });

    HapticFeedback.selectionClick();

    // In speed mode, auto-confirm and move to next question (skip for checkbox - needs manual confirm)
    if (_isSpeedMode && q.type != QuestionType.checkbox) {
      Future.delayed(const Duration(milliseconds: 300), _handleNext);
    }
  }

  void _onEssayChanged(String value) {
    setState(() {
      _essayAnswers[_currentIndex] = value;
    });
  }

  void _handleNext() {
    // Process answer
    if (!_processedIndices.contains(_currentIndex)) {
      _processedIndices.add(_currentIndex);
    }

    if (_currentIndex < _sessionQuestions.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _resetQuestionTimer();
    } else {
      _submitExam();
    }
  }

  void _handlePrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  Future<void> _submitExam({bool auto = false}) async {
    _timer?.cancel();

    final authService = context.read<AuthService>();
    final navigator = Navigator.of(context);

    if (!auto && _currentIndex < _sessionQuestions.length - 1) {
      final String? action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'إنهاء الاختبار؟',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text('إكمال', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'submit'),
              child: Text('تسليم', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      );

      if (action != 'submit') {
        _startTimer();
        return;
      }
    }

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      int correctCount = 0;
      List<Map<String, dynamic>> results = [];
      final Set<String> countedIds = {};

      for (int i = 0; i < _sessionQuestions.length; i++) {
        final q = _sessionQuestions[i];
        final String qId = q.id ?? 'mock_q_${q.number}';
        if (countedIds.contains(qId)) continue;
        countedIds.add(qId);

        final userAns = _userAnswers[i] ?? {};
        final essayAns = _essayAnswers[i] ?? '';
        
        bool isCorrect = false;
        if (q.type == QuestionType.checkbox) {
          isCorrect = userAns.length == q.correctOptionIds.length &&
              userAns.every((id) => q.correctOptionIds.contains(id));
        } else if (q.type == QuestionType.essay) {
          // Essay questions are not auto-graded as correct/wrong during exam submission
          // we treat them as unanswered/pending for now, or just not correct.
          isCorrect = false; 
        } else {
          isCorrect = userAns.length == 1 &&
              q.correctOptionIds.contains(userAns.first);
        }

        if (isCorrect) correctCount++;

        results.add({
          'questionId': qId,
          'selectedOptionId': userAns,
          'essayAnswer': essayAns,
          'isCorrect': isCorrect,
          'topicIds': q.topicIds,
        });
      }

      final score = (correctCount / widget.questions.length) * 100;
      final timeSpent = _hasNoTimer
          ? 0
          : (_isSpeedMode ? 0 : widget.config.durationSeconds - _timeLeft);

      final userId = authService.user?.uid;
      if (userId != null && widget.config.id != null) {
        await _examService.recordExamAttempt(
          userId: userId,
          examId: widget.config.id!,
          score: score,
          timeSpentSeconds: timeSpent,
          answers: results,
          subjectId: widget.config.subjectId,
          examTitle: widget.config.title,
          totalQuestions: widget.questions.length,
          correctCount: correctCount,
        );
        for (var res in results) {
          await _srsService.updateMastery(
            userId: userId,
            questionId: res['questionId'],
            subjectId: widget.config.subjectId,
            quality: res['isCorrect'] ? 5 : 0,
          );
        }

        final mappedAnswers = results.map((r) => {
          'questionId': r['questionId'],
          'isCorrect': r['isCorrect'],
          'timeSpent': results.isNotEmpty ? (timeSpent / results.length).round() : 0,
        }).toList();

        final gamificationService = GamificationService();
        final subjectLeagueService = SubjectLeagueService();

        gamificationService.processQuizAttempt(userId, mappedAnswers, widget.questions).then((result) {
          final userName = authService.user?.displayName ?? 
                           authService.user?.email?.split('@').first ?? 
                           'طالب';
          final userAvatar = authService.user?.photoURL;
          subjectLeagueService.addSubjectXp(
            userId: userId,
            subjectId: widget.config.subjectId,
            xpGained: result.xpGained,
            userName: userName,
            userAvatar: userAvatar,
          );
        });
      }

      if (mounted) navigator.pop(); // Close loading

      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExamResultScreen(
            config: widget.config,
            score: score,
            correctCount: correctCount,
            totalCount: widget.questions.length,
            timeSpentSeconds: timeSpent,
            questions: widget.questions,
            userAnswers: {
              ..._userAnswers,
              ..._essayAnswers,
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        navigator.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark || _isSpeedMode;
    final q = _sessionQuestions[_currentIndex];
    final progress = (_currentIndex + 1) / _sessionQuestions.length;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          if (!_hasNoTimer)
            LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark
                    ? Colors.blueAccent
                    : (_timeLeft < 60 ? Colors.red : AppColors.primaryBlue),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuestionCard(q, isDark),
                  const SizedBox(height: 24),
                  _buildOptions(q, isDark),
                  const SizedBox(height: 32),
                  _buildNavigationButtons(isDark),
                  const SizedBox(height: 40), // Extra space at bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentIndex > 0)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: OutlinedButton.icon(
                onPressed: _handlePrevious,
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white70 : AppColors.primaryBlue,
                ),
                label: Text(
                  'السابق',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : AppColors.primaryBlue,
                  side: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _handleNext,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? const Color(0xFF38BDF8) : AppColors.primaryBlue,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentIndex < _sessionQuestions.length - 1
                      ? 'التالي'
                      : 'تسليم الاختبار',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Icon(
                  _currentIndex < _sessionQuestions.length - 1
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.check_circle_rounded,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? Colors.transparent : Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'سؤال ${_currentIndex + 1} / ${_sessionQuestions.length}',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
          _buildTimerWidget(isDark),
          if (!_isSpeedMode)
            TextButton(
              onPressed: () => _submitExam(),
              child: Text(
                'إنهاء',
                style: GoogleFonts.cairo(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white70 : AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerWidget(bool isDark) {
    if (_hasNoTimer) {
      return const SizedBox.shrink(); // Hide timer for no-limit exams
    }

    final isWarning =
        !_isSpeedMode && _timeLeft < 60 || _isSpeedMode && _timeLeft <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isWarning
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWarning ? Colors.red : AppColors.primaryBlue,
          width: _isSpeedMode ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: isWarning ? Colors.red : AppColors.primaryBlue,
          ),
          const SizedBox(width: 6),
          Text(
            _formatTime(_timeLeft),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: _isSpeedMode ? 18 : 14,
              color: isWarning ? Colors.red : AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion q, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TexViewWidget(
            text: q.text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          if (q.type == QuestionType.essay) ...[
            const SizedBox(height: 24),
            TextField(
              maxLines: 6,
              style: GoogleFonts.cairo(color: isDark ? Colors.white : Colors.black),
              onChanged: _onEssayChanged,
              decoration: InputDecoration(
                hintText: 'اكتب إجابتك هنا...',
                hintStyle: GoogleFonts.cairo(color: isDark ? Colors.white38 : Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptions(QuizQuestion q, bool isDark) {
    return Column(
      children: (q.options ?? []).map((opt) {
        final selections = _userAnswers[_currentIndex] ?? {};
        final isSelected = selections.contains(opt.id);

        Color borderColor = isDark ? Colors.white24 : AppColors.borderLight;
        Color bgColor = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white;

        if (isSelected) {
          borderColor = isDark ? Colors.blueAccent : AppColors.primaryBlue;
          bgColor = isSelected ? (borderColor.withValues(alpha: 0.1)) : bgColor;
        }

        final bool isCheckbox = q.type == QuestionType.checkbox;

        return GestureDetector(
          onTap: () => _selectOption(opt.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TexViewWidget(
                    text: opt.text,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: isCheckbox ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isCheckbox ? BorderRadius.circular(6) : null,
                    border: Border.all(color: isSelected ? borderColor : Colors.grey.withValues(alpha: 0.3), width: 2),
                    color: isSelected ? borderColor : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(
                          isCheckbox ? Icons.check_rounded : Icons.circle,
                          size: isCheckbox ? 14 : 8,
                          color: isDark ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

}
