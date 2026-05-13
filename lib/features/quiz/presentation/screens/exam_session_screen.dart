import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/exam_service.dart';
import 'package:quizzly/features/quiz/domain/services/spaced_repetition_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_result_screen.dart';

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
  final Map<int, String> _userAnswers = {}; // index -> optionId
  
  late int _timeLeft; // Total time or Per-question time
  bool _isSpeedMode = false;
  Timer? _timer;
  late List<QuizQuestion> _sessionQuestions;
  final Set<int> _processedIndices = {}; 

  @override
  void initState() {
    super.initState();
    _isSpeedMode = widget.initialSpeedMode;
    _timeLeft = _isSpeedMode ? 10 : widget.config.durationSeconds;
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
    if (_isSpeedMode) return seconds.toString();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _selectOption(String optionId) {
    if (_processedIndices.contains(_currentIndex)) return;

    setState(() {
      _userAnswers[_currentIndex] = optionId;
    });

    HapticFeedback.selectionClick();
    
    if (_isSpeedMode) {
      // In speed mode, auto-confirm after selection to keep the pace
      Future.delayed(const Duration(milliseconds: 300), _handleNext);
    }
  }

  void _handleNext() {
    if (_timer == null || !_timer!.isActive && !_isSpeedMode) return;

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

  Future<void> _submitExam({bool auto = false}) async {
    _timer?.cancel();
    
    final authService = context.read<AuthService>();
    final navigator = Navigator.of(context);

    if (!auto && _currentIndex < _sessionQuestions.length - 1) {
      final String? action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('إنهاء الاختبار؟', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: Text('إكمال', style: GoogleFonts.cairo())),
            ElevatedButton(onPressed: () => Navigator.pop(context, 'submit'), child: Text('تسليم', style: GoogleFonts.cairo())),
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
        showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      }

      int correctCount = 0;
      List<Map<String, dynamic>> results = [];
      final Set<String> countedIds = {};

      for (int i = 0; i < _sessionQuestions.length; i++) {
        final q = _sessionQuestions[i];
        final String qId = q.id ?? 'mock_q_${q.number}';
        if (countedIds.contains(qId)) continue;
        countedIds.add(qId);

        final userAns = _userAnswers[i];
        final isCorrect = userAns != null && q.correctOptionIds.contains(userAns);
        if (isCorrect) correctCount++;

        results.add({
          'questionId': qId,
          'selectedOptionId': userAns,
          'isCorrect': isCorrect,
          'topicIds': q.topicIds,
        });
      }

      final score = (correctCount / widget.questions.length) * 100;
      final timeSpent = _isSpeedMode ? 0 : widget.config.durationSeconds - _timeLeft;

      final userId = authService.user?.uid;
      if (userId != null && widget.config.id != null) {
        await _examService.recordExamAttempt(
          userId: userId,
          examId: widget.config.id!,
          score: score,
          timeSpentSeconds: timeSpent,
          answers: results,
        );
        for (var res in results) {
          await _srsService.updateMastery(
            userId: userId,
            questionId: res['questionId'],
            subjectId: widget.config.subjectId,
            quality: res['isCorrect'] ? 5 : 0,
          );
        }
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
            userAnswers: _userAnswers,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _sessionQuestions[_currentIndex];
    final progress = (_currentIndex + 1) / _sessionQuestions.length;

    return Scaffold(
      backgroundColor: _isSpeedMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: _isSpeedMode ? Colors.white10 : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _isSpeedMode ? Colors.blueAccent : (_timeLeft < 60 ? Colors.red : AppColors.primaryBlue),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuestionCard(q),
                  const SizedBox(height: 24),
                  _buildOptions(q),
                ],
              ),
            ),
          ),
          if (!_isSpeedMode) SafeArea(child: _buildNavigationFooter()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _isSpeedMode ? Colors.transparent : Colors.white,
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
              color: _isSpeedMode ? Colors.white70 : AppColors.textPrimary
            ),
          ),
          _buildTimerWidget(),
          if (!_isSpeedMode)
            TextButton(
              onPressed: () => _submitExam(),
              child: Text('إنهاء', style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
            )
          else
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerWidget() {
    final isWarning = !_isSpeedMode && _timeLeft < 60 || _isSpeedMode && _timeLeft <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isWarning ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isWarning ? Colors.red : AppColors.primaryBlue, width: _isSpeedMode ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: isWarning ? Colors.red : AppColors.primaryBlue),
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

  Widget _buildQuestionCard(QuizQuestion q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isSpeedMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: _isSpeedMode ? Border.all(color: Colors.white10) : null,
        boxShadow: _isSpeedMode ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Text(
        q.text,
        style: GoogleFonts.cairo(
          fontSize: 18, 
          fontWeight: FontWeight.bold, 
          height: 1.6,
          color: _isSpeedMode ? Colors.white : AppColors.textPrimary
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      ),
    );
  }

  Widget _buildOptions(QuizQuestion q) {
    return Column(
      children: (q.options ?? []).map((opt) {
        final isSelected = _userAnswers[_currentIndex] == opt.id;
        
        Color borderColor = _isSpeedMode ? Colors.white24 : AppColors.borderLight;
        Color bgColor = _isSpeedMode ? Colors.white.withValues(alpha: 0.05) : Colors.white;

        if (isSelected) {
          borderColor = _isSpeedMode ? Colors.blueAccent : AppColors.primaryBlue;
          bgColor = isSelected ? (borderColor.withValues(alpha: 0.1)) : bgColor;
        }

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
                  child: Text(
                    opt.text,
                    style: GoogleFonts.cairo(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: _isSpeedMode ? Colors.white : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentIndex > 0)
            OutlinedButton(
              onPressed: () => setState(() => _currentIndex--),
              child: Text('السابق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox(width: 80),
          
          ElevatedButton(
            onPressed: _handleNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _currentIndex < _sessionQuestions.length - 1 ? 'التالي' : 'تسليم الاختبار',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
