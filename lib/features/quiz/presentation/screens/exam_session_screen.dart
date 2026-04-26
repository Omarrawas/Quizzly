import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/exam_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_result_screen.dart';

class ExamSessionScreen extends StatefulWidget {
  final ExamConfig config;
  final List<QuizQuestion> questions;

  const ExamSessionScreen({
    super.key,
    required this.config,
    required this.questions,
  });

  @override
  State<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<ExamSessionScreen> {
  final ExamService _examService = ExamService();
  int _currentIndex = 0;
  final Map<int, String> _userAnswers = {}; // index -> optionId
  
  late int _timeLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.config.durationSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _submitExam(auto: true);
      }
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _selectOption(String optionId) {
    setState(() {
      _userAnswers[_currentIndex] = optionId;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _submitExam({bool auto = false}) async {
    _timer?.cancel();
    
    final authService = context.read<AuthService>();
    final navigator = Navigator.of(context);

    if (!auto) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('إنهاء الاختبار؟', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من رغبتك في تسليم الإجابات؟', style: GoogleFonts.cairo()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('تسليم', style: GoogleFonts.cairo())),
          ],
        ),
      );
      if (confirm != true) {
        _startTimer();
        return;
      }
    }

    // Calculate Results
    int correctCount = 0;
    List<Map<String, dynamic>> results = [];

    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final userAns = _userAnswers[i];
      final isCorrect = q.correctOptionIds.contains(userAns);
      if (isCorrect) correctCount++;
      
      results.add({
        'questionId': q.id,
        'selectedOptionId': userAns,
        'isCorrect': isCorrect,
        'topicIds': q.topicIds,
      });
    }

    final score = (correctCount / widget.questions.length) * 100;
    final timeSpent = widget.config.durationSeconds - _timeLeft;

    final userId = authService.user?.uid;
    if (userId != null && widget.config.id != null) {
      await _examService.recordExamAttempt(
        userId: userId,
        examId: widget.config.id!,
        score: score,
        timeSpentSeconds: timeSpent,
        answers: results,
      );
    }

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
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_currentIndex];
    final progress = (_currentIndex + 1) / widget.questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _timeLeft < 60 ? Colors.red : AppColors.primaryBlue,
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
          _buildNavigationFooter(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'سؤال ${_currentIndex + 1} / ${widget.questions.length}',
            style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _timeLeft < 60 ? Colors.red[50] : Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: _timeLeft < 60 ? Colors.red : AppColors.primaryBlue),
                const SizedBox(width: 6),
                Text(
                  _formatTime(_timeLeft),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: _timeLeft < 60 ? Colors.red : AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _submitExam(),
            child: Text('إنهاء', style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Text(
        q.text,
        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600, height: 1.6),
        textDirection: TextDirection.rtl,
      ),
    );
  }

  Widget _buildOptions(QuizQuestion q) {
    return Column(
      children: (q.options ?? []).map((opt) {
        final isSelected = _userAnswers[_currentIndex] == opt.id;
        return GestureDetector(
          onTap: () => _selectOption(opt.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? AppColors.primaryBlue : Colors.grey),
                    color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    opt.text,
                    style: GoogleFonts.cairo(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                    ),
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
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('السابق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox(width: 80),
          
          ElevatedButton(
            onPressed: _currentIndex < widget.questions.length - 1
                ? () => setState(() => _currentIndex++)
                : () => _submitExam(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _currentIndex < widget.questions.length - 1 ? 'التالي' : 'تسليم الاختبار',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
