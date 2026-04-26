import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/smart_quiz_service.dart';
import 'package:quizzly/features/quiz/domain/services/practice_service.dart';
import 'package:quizzly/features/gamification/domain/services/gamification_service.dart';

class SmartQuizSessionScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const SmartQuizSessionScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SmartQuizSessionScreen> createState() => _SmartQuizSessionScreenState();
}

class _SmartQuizSessionScreenState extends State<SmartQuizSessionScreen>
    with SingleTickerProviderStateMixin {
  final SmartQuizService _smartService = SmartQuizService();
  final PracticeService _practiceService = PracticeService();
  final GamificationService _gamificationService = GamificationService();

  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  String? _selectedOptionId;
  AnswerState _answerState = AnswerState.unanswered;
  bool _loading = true;
  
  // Track answers for mastery update
  final List<Map<String, dynamic>> _userAnswers = [];

  // Stats
  int _correct = 0;
  int _wrong = 0;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _loadSmartQuiz();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadSmartQuiz() async {
    final userId = context.read<AuthService>().user?.uid;
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      final questions = await _smartService.generateSmartQuiz(
        userId: userId,
        subjectId: widget.subjectId,
        totalQuestions: 10,
      );
      if (mounted) {
        setState(() {
          _questions = questions;
          _loading = false;
        });
        if (_questions.isNotEmpty) _slideController.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  QuizQuestion? get _current =>
      _questions.isNotEmpty && _currentIndex < _questions.length
          ? _questions[_currentIndex]
          : null;

  void _selectOption(String optionId) {
    if (_answerState != AnswerState.unanswered) return;
    HapticFeedback.selectionClick();

    final isCorrect = _current!.correctOptionIds.contains(optionId);
    
    // Add to answer list for final update
    _userAnswers.add({
      'questionId': _current!.id,
      'isCorrect': isCorrect,
    });

    setState(() {
      _selectedOptionId = optionId;
      _answerState = isCorrect ? AnswerState.correct : AnswerState.wrong;
      if (isCorrect) {
        _correct++;
      } else {
        _wrong++;
      }
    });

    // Still record individual question analytics
    if (_current?.id != null) {
      _practiceService.recordAnswer(
        questionId: _current!.id!,
        isCorrect: isCorrect,
        timeSpentSeconds: 0,
      );
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionId = null;
        _answerState = AnswerState.unanswered;
      });
      _slideController.forward(from: 0);
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    final userId = context.read<AuthService>().user?.uid;
    if (userId != null && _userAnswers.isNotEmpty) {
      // 1. Update Mastery levels
      _smartService.updateTopicPerformance(userId, widget.subjectId, _userAnswers, _questions);
      
      // 2. Update Gamification (XP, Streak, Level)
      // Map user answers to the format expected by GamificationService
      final mappedAnswers = _userAnswers.map((a) => {
        'questionId': a['questionId'],
        'isCorrect': a['isCorrect'],
        'timeSpent': 30, // Default for now
      }).toList();
      
      _gamificationService.processQuizAttempt(userId, mappedAnswers, _questions);
    }
    _showResultsSheet();
  }

  void _showResultsSheet() {
    final total = _correct + _wrong;
    final pct = total > 0 ? (_correct / total * 100).round() : 0;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('كويز ذكي مكتمل!', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildResultCircle(pct),
            const SizedBox(height: 24),
            Text('لقد قمت بتحسين مستوى إتقانك للمادة 🎉', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close sheet
                  Navigator.pop(context); // Back to Hub
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('العودة للمركز', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCircle(int pct) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryBlue, width: 2),
      ),
      child: Center(
        child: Text('$pct%', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isDark),
      body: _loading
          ? _buildLoadingState()
          : _questions.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildProgressBar(),
                    Expanded(
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildQuestionCard(isDark),
                              const SizedBox(height: 16),
                              if (_current?.options != null) _buildOptions(isDark),
                              const SizedBox(height: 12),
                              if (_answerState != AnswerState.unanswered && _current?.explanation != null)
                                _buildExplanationCard(isDark),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildActionBar(isDark),
                  ],
                ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text('جاري تحليل أداءك وتجهيز الأسئلة...', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        children: [
          Text('كويز ذكي', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
          if (!_loading)
            Text('السؤال ${_currentIndex + 1} من ${_questions.length}', 
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _questions.isNotEmpty ? (_currentIndex + 1) / _questions.length : 0.0;
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.grey[200],
      valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
      minHeight: 3,
    );
  }

  Widget _buildQuestionCard(bool isDark) {
    final q = _current!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.text,
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary, height: 1.6),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(bool isDark) {
    final q = _current!;
    return Column(
      children: q.options!.map((option) {
        final isSelected = _selectedOptionId == option.id;
        final isCorrect = q.correctOptionIds.contains(option.id);
        final revealed = _answerState != AnswerState.unanswered;

        Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        Color borderColor = isDark ? Colors.white12 : AppColors.borderLight;
        
        if (revealed) {
          if (isCorrect) {
            bgColor = const Color(0xFFF0FDF4);
            borderColor = const Color(0xFF16A34A);
          } else if (isSelected) {
            bgColor = const Color(0xFFFEF2F2);
            borderColor = const Color(0xFFDC2626);
          }
        } else if (isSelected) {
          borderColor = AppColors.primaryBlue;
        }

        return GestureDetector(
          onTap: () => _selectOption(option.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: (isSelected || (revealed && isCorrect)) ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Expanded(child: Text(option.text, style: GoogleFonts.cairo(), textDirection: TextDirection.rtl)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExplanationCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFEFCE8), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE047))),
      child: Text(_current!.explanation!, style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF78350F))),
    );
  }

  Widget _buildActionBar(bool isDark) {
    final answered = _answerState != AnswerState.unanswered;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: answered ? _nextQuestion : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            _currentIndex == _questions.length - 1 ? 'عرض النتائج' : 'السؤال التالي',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('لا توجد بيانات كافية', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('ابدأ بالتدريب العادي أولاً لنتمكن من تحليل مستواك.', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('العودة')),
        ],
      ),
    );
  }
}
