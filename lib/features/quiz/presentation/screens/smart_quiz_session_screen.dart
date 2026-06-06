import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/smart_quiz_service.dart';
import 'package:quizzly/features/quiz/domain/services/practice_service.dart';
import 'package:quizzly/features/gamification/domain/services/gamification_service.dart';
import 'package:quizzly/features/gamification/domain/services/subject_league_service.dart';

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
  Set<String> _selectedOptionIds = {};
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

    setState(() {
      if (_current?.type == QuestionType.checkbox) {
        final newSelection = Set<String>.from(_selectedOptionIds);
        if (newSelection.contains(optionId)) {
          newSelection.remove(optionId);
        } else {
          newSelection.add(optionId);
        }
        _selectedOptionIds = newSelection;
      } else {
        // Single choice - immediate reveal
        _selectedOptionIds = {optionId};
        _checkAnswer();
      }
    });
  }

  void _checkAnswer() {
    if (_selectedOptionIds.isEmpty) return;
    
    final q = _current!;
    bool isCorrect = false;
    
    if (q.type == QuestionType.checkbox) {
      isCorrect = _selectedOptionIds.length == q.correctOptionIds.length &&
          _selectedOptionIds.every((id) => q.correctOptionIds.contains(id));
    } else {
      isCorrect = _selectedOptionIds.length == 1 &&
          q.correctOptionIds.contains(_selectedOptionIds.first);
    }
    
    // Add to answer list for final update
    _userAnswers.add({
      'questionId': q.id,
      'isCorrect': isCorrect,
    });

    setState(() {
      _answerState = isCorrect ? AnswerState.correct : AnswerState.wrong;
      if (isCorrect) {
        _correct++;
      } else {
        _wrong++;
      }
    });

    // Still record individual question analytics
    if (q.id != null) {
      _practiceService.recordAnswer(
        questionId: q.id!,
        isCorrect: isCorrect,
        timeSpentSeconds: 0,
      );
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIds = {};
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
      
      final auth = context.read<AuthService>();
      final userName = auth.user?.displayName ?? 
                       auth.user?.email?.split('@').first ?? 
                       'طالب';
      final userAvatar = auth.user?.photoURL;

      _gamificationService.processQuizAttempt(userId, mappedAnswers, _questions).then((result) {
        SubjectLeagueService().addSubjectXp(
          userId: userId,
          subjectId: widget.subjectId,
          xpGained: result.xpGained,
          userName: userName,
          userAvatar: userAvatar,
        );
      });
    }
    _showResultsSheet();
  }

  void _showResultsSheet() {
    final total = _correct + _wrong;
    final pct = total > 0 ? (_correct / total * 100).round() : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'كويز ذكي مكتمل!', 
              style: GoogleFonts.cairo(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              )
            ),
            const SizedBox(height: 20),
            _buildResultCircle(pct, isDark),
            const SizedBox(height: 24),
            Text(
              'لقد قمت بتحسين مستوى إتقانك للمادة 🎉', 
              style: GoogleFonts.cairo(color: isDark ? Colors.white70 : AppColors.textSecondary)
            ),
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

  Widget _buildResultCircle(int pct, bool isDark) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryBlue, width: 2),
      ),
      child: Center(
        child: Text(
          '$pct%', 
          style: GoogleFonts.inter(
            fontSize: 24, 
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.white : AppColors.primaryBlue
          )
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isDark),
      body: _loading
          ? _buildLoadingState(isDark)
          : _questions.isEmpty
              ? _buildEmptyState(isDark)
              : Column(
                  children: [
                    _buildProgressBar(isDark),
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

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'جاري تحليل أداءك وتجهيز الأسئلة...', 
            style: GoogleFonts.cairo(color: isDark ? Colors.white60 : AppColors.textSecondary)
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Column(
        children: [
          Text(
            'كويز ذكي', 
            style: GoogleFonts.cairo(
              fontSize: 14, 
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            )
          ),
          if (!_loading)
            Text(
              'السؤال ${_currentIndex + 1} من ${_questions.length}', 
              style: GoogleFonts.cairo(
                fontSize: 11, 
                color: isDark ? Colors.white38 : AppColors.textSecondary
              )
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    final progress = _questions.isNotEmpty ? (_currentIndex + 1) / _questions.length : 0.0;
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
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
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), 
            blurRadius: 10, 
            offset: const Offset(0, 2)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TexViewWidget(
            text: q.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(bool isDark) {
    final q = _current!;
    return Column(
      children: q.options!.map((option) {
        final isSelected = _selectedOptionIds.contains(option.id);
        final isCorrect = q.correctOptionIds.contains(option.id);
        final revealed = _answerState != AnswerState.unanswered;

        Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        Color borderColor = isDark ? Colors.white10 : AppColors.borderLight;
        Color textColor = isDark ? Colors.white : AppColors.textPrimary;
        
        if (revealed) {
          if (isCorrect) {
            bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4);
            borderColor = isDark ? const Color(0xFF059669) : const Color(0xFF16A34A);
            textColor = isDark ? Colors.white : const Color(0xFF166534);
          } else if (isSelected) {
            bgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
            borderColor = isDark ? const Color(0xFFDC2626) : const Color(0xFFDC2626);
            textColor = isDark ? Colors.white : const Color(0xFF991B1B);
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
              border: Border.all(
                color: borderColor, 
                width: (isSelected || (revealed && isCorrect)) ? 1.5 : 1
              ),
            ),
            child: Row(
              children: [
                if (q.type == QuestionType.checkbox) ...[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSelected ? borderColor : Colors.grey.withValues(alpha: 0.3), width: 2),
                      color: isSelected ? borderColor : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TexViewWidget(
                    text: option.text,
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (q.type != QuestionType.checkbox) ...[
                  // For MCQ, we show a subtle indicator or nothing if we want consistency
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? borderColor : Colors.grey.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: isSelected ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: borderColor))) : null,
                  ),
                ],
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
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF422006).withValues(alpha: 0.3) : const Color(0xFFFEFCE8), 
        borderRadius: BorderRadius.circular(14), 
        border: Border.all(color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE047))
      ),
      child: TexViewWidget(
        text: _current!.explanation!,
        fontSize: 13,
        color: isDark ? const Color(0xFFFDE047) : const Color(0xFF78350F),
      ),
    );
  }

  Widget _buildActionBar(bool isDark) {
    final answered = _answerState != AnswerState.unanswered;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: isDark ? const Border(top: BorderSide(color: Colors.white10)) : null,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: answered 
              ? _nextQuestion 
              : (_current?.type == QuestionType.checkbox && _selectedOptionIds.isNotEmpty ? _checkAnswer : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: (answered || (!answered && _current?.type == QuestionType.checkbox && _selectedOptionIds.isNotEmpty)) 
                ? AppColors.primaryBlue 
                : Colors.grey[300],
            foregroundColor: (answered || (!answered && _current?.type == QuestionType.checkbox && _selectedOptionIds.isNotEmpty)) 
                ? Colors.white 
                : Colors.grey[600],
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            answered
                ? (_currentIndex == _questions.length - 1 ? 'عرض النتائج' : 'السؤال التالي')
                : 'تحقق من الإجابة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 64, color: isDark ? Colors.white10 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد بيانات كافية', 
            style: GoogleFonts.cairo(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary
            )
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بالتدريب العادي أولاً لنتمكن من تحليل مستواك.', 
            style: GoogleFonts.cairo(color: isDark ? Colors.white38 : AppColors.textSecondary)
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('العودة')
          ),
        ],
      ),
    );
  }

}
