import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/spaced_repetition_service.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';

class SpeedModeSessionScreen extends StatefulWidget {
  final ExamConfig config;
  final List<QuizQuestion> questions;

  const SpeedModeSessionScreen({
    super.key,
    required this.config,
    required this.questions,
  });

  @override
  State<SpeedModeSessionScreen> createState() => _SpeedModeSessionScreenState();
}

class _SpeedModeSessionScreenState extends State<SpeedModeSessionScreen> {
  final SpacedRepetitionService _srs = SpacedRepetitionService();
  int _currentIndex = 0;
  int _timerValue = 10;
  Timer? _timer;
  bool _answered = false;
  String? _selectedOptionId;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timerValue = 10;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerValue > 0) {
        setState(() => _timerValue--);
      } else {
        _onTimeUp();
      }
    });
  }

  void _onTimeUp() {
    _timer?.cancel();
    if (!_answered) {
      _selectOption(null); // Mark as wrong
    }
  }

  void _selectOption(String? optionId) async {
    if (_answered) return;
    
    _timer?.cancel();
    _answered = true;
    _selectedOptionId = optionId;

    final q = widget.questions[_currentIndex];
    final isCorrect = optionId != null && q.correctOptionIds.contains(optionId);
    if (isCorrect) _score++;

    // Update SRS
    final userId = context.read<AuthService>().user?.uid;
    if (userId != null) {
      await _srs.updateMastery(
        userId: userId,
        questionId: q.id!,
        subjectId: widget.config.subjectId,
        quality: isCorrect ? 5 : 0,
      );
    }

    setState(() {});
    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        if (_currentIndex < widget.questions.length - 1) {
          setState(() {
            _currentIndex++;
            _answered = false;
            _selectedOptionId = null;
            _startTimer();
          });
        } else {
          _showResults();
        }
      }
    });
  }

  void _showResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('انتهى التحدي! ⚡', style: GoogleFonts.cairo(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('لقد أجبت على $_score من أصل ${widget.questions.length} سؤالاً بسرعة البرق!', textAlign: TextAlign.center, style: GoogleFonts.cairo()),
            const SizedBox(height: 20),
            Text('${((_score/widget.questions.length)*100).round()}%', style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              child: Text('العودة للمركز', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_currentIndex];
    final progress = (_currentIndex + 1) / widget.questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate for speed mode
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('سؤال ${_currentIndex + 1}/${widget.questions.length}', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14)),
            _buildTimerDisplay(),
            Text('النقاط: $_score', style: GoogleFonts.cairo(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(Colors.blueAccent)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    q.text,
                    style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  ... (q.options ?? []).map((opt) => _buildOption(opt, q)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _timerValue <= 3 ? Colors.red.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _timerValue <= 3 ? Colors.red : Colors.blueAccent, width: 2),
      ),
      child: Text(
        '$_timerValue',
        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _timerValue <= 3 ? Colors.red : Colors.blueAccent),
      ),
    );
  }

  Widget _buildOption(QuizOption opt, QuizQuestion q) {
    bool isCorrect = q.correctOptionIds.contains(opt.id);
    bool isSelected = _selectedOptionId == opt.id;
    
    Color borderColor = Colors.white24;
    Color bgColor = Colors.white.withValues(alpha: 0.05);

    if (_answered) {
      if (isCorrect) {
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.2);
      } else if (isSelected) {
        borderColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.2);
      }
    }

    return GestureDetector(
      onTap: () => _selectOption(opt.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Center(
          child: Text(
            opt.text,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
