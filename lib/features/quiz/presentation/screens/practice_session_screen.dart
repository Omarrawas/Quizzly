import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/practice_service.dart';
import 'package:quizzly/features/quiz/domain/services/smart_quiz_service.dart';
import 'package:quizzly/features/gamification/domain/services/gamification_service.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';

class PracticeSessionScreen extends StatefulWidget {
  final String subjectId;
  final List<String>? topicIds;
  final List<String> topicNames;
  final Difficulty? selectedDifficulty;

  const PracticeSessionScreen({
    super.key,
    required this.subjectId,
    this.topicIds,
    required this.topicNames,
    this.selectedDifficulty,
  });

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen>
    with SingleTickerProviderStateMixin {
  final PracticeService _service = PracticeService();
  final SmartQuizService _smartService = SmartQuizService();
  final GamificationService _gamificationService = GamificationService();

  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  String? _selectedOptionId;
  AnswerState _answerState = AnswerState.unanswered;
  bool _showExplanation = false;
  bool _loading = true;
  bool _loadingSimilar = false;

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
    _loadQuestions();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    try {
      final questions = await _service.fetchPracticeQuestions(
        subjectId: widget.subjectId,
        topicIds: widget.topicIds,
        difficulty: widget.selectedDifficulty,
        limit: 30,
      );
      if (mounted) {
        setState(() {
          _questions = questions;
          _loading = false;
        });
        _slideController.forward(from: 0);
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
    setState(() {
      _selectedOptionId = optionId;
      _answerState = isCorrect ? AnswerState.correct : AnswerState.wrong;
      if (isCorrect) {
        _correct++;
      } else {
        _wrong++;
        _showExplanation = true; // Auto-show explanation on wrong
      }
    });

    // Add to answer list for final update
    _userAnswers.add({
      'questionId': _current!.id,
      'isCorrect': isCorrect,
    });

    if (_current?.id != null) {
      _service.recordAnswer(
        questionId: _current!.id!,
        isCorrect: isCorrect,
        timeSpentSeconds: 0,
      );
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      _slideController.forward(from: 0);
      setState(() {
        _currentIndex++;
        _selectedOptionId = null;
        _answerState = AnswerState.unanswered;
        _showExplanation = false;
      });
      _slideController.forward(from: 0);
    } else {
      _showResultsSheet();
    }
  }

  Future<void> _loadSimilarQuestion() async {
    final q = _current;
    if (q == null || q.id == null) return;
    HapticFeedback.mediumImpact();

    setState(() => _loadingSimilar = true);

    final similar = await _service.fetchSimilarQuestion(
      subjectId: widget.subjectId,
      currentQuestionId: q.id!,
      topicIds: q.topicIds ?? widget.topicIds ?? [],
      difficulty: q.difficulty ?? Difficulty.medium,
    );

    if (!mounted) return;

    if (similar != null) {
      setState(() {
        _questions.insert(_currentIndex + 1, similar);
        _loadingSimilar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة سؤال مشابه!', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.primaryBlue,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      setState(() => _loadingSimilar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا توجد أسئلة مشابهة متاحة', style: GoogleFonts.cairo()),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showResultsSheet() {
    final userId = context.read<AuthService>().user?.uid;
    if (userId != null && _userAnswers.isNotEmpty) {
      // 1. Update Mastery levels
      _smartService.updateTopicPerformance(userId, widget.subjectId, _userAnswers, _questions);
      
      // 2. Update Gamification (XP, Streak, Level)
      final mappedAnswers = _userAnswers.map((a) => {
        'questionId': a['questionId'],
        'isCorrect': a['isCorrect'],
        'timeSpent': 30,
      }).toList();
      _gamificationService.processQuizAttempt(userId, mappedAnswers, _questions);
    }

    final total = _correct + _wrong;
    final pct = total > 0 ? (_correct / total * 100).round() : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$pct%',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'انتهت الجلسة!',
              style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBadge('✅ صحيح', '$_correct', const Color(0xFF16A34A)),
                _buildStatBadge('❌ خطأ', '$_wrong', const Color(0xFFDC2626)),
                _buildStatBadge('📊 الكل', '${_correct + _wrong}', AppColors.primaryBlue),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('خروج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentIndex = 0;
                        _selectedOptionId = null;
                        _answerState = AnswerState.unanswered;
                        _showExplanation = false;
                        _correct = 0;
                        _wrong = 0;
                      });
                      _loadQuestions();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('جلسة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: GoogleFonts.cairo(fontSize: 11, color: color)),
        ],
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
          ? const Center(child: CircularProgressIndicator())
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
                              if (_answerState != AnswerState.unanswered &&
                                  _current?.explanation != null)
                                _buildExplanationCard(isDark),
                              const SizedBox(height: 80),
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

  PreferredSizeWidget _buildAppBar(bool isDark) {
    final total = _correct + _wrong;
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        children: [
          Text(
            widget.topicNames.length == 1
                ? widget.topicNames.first
                : '${widget.topicNames.length} مواضيع',
            style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            'السؤال ${_currentIndex + 1} من ${_questions.length}',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        if (total > 0)
          Container(
            margin: const EdgeInsets.only(left: 16, right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Text('✅ $_correct', style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF16A34A))),
                const SizedBox(width: 8),
                Text('❌ $_wrong', style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFFDC2626))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = _questions.isNotEmpty ? (_currentIndex + 1) / _questions.length : 0.0;
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.grey[200],
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
      minHeight: 3,
    );
  }

  Widget _buildQuestionCard(bool isDark) {
    final q = _current!;
    final diffColor = q.difficulty == Difficulty.easy
        ? const Color(0xFF16A34A)
        : q.difficulty == Difficulty.hard
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706);

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
          Row(
            children: [
              if (q.difficulty != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    q.difficulty!.name == 'easy' ? 'سهل' : q.difficulty!.name == 'hard' ? 'صعب' : 'متوسط',
                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: diffColor),
                  ),
                ),
              const Spacer(),
              if (q.tagLabel != null)
                Text(q.tagLabel!, style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            q.text,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
              height: 1.6,
            ),
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
        Color textColor = isDark ? Colors.white : AppColors.textPrimary;
        IconData? trailingIcon;

        if (revealed) {
          if (isCorrect) {
            bgColor = const Color(0xFFF0FDF4);
            borderColor = const Color(0xFF16A34A);
            textColor = const Color(0xFF166534);
            trailingIcon = Icons.check_circle_rounded;
          } else if (isSelected) {
            bgColor = const Color(0xFFFEF2F2);
            borderColor = const Color(0xFFDC2626);
            textColor = const Color(0xFF991B1B);
            trailingIcon = Icons.cancel_rounded;
          }
        } else if (isSelected) {
          bgColor = AppColors.primaryBlue.withValues(alpha: 0.08);
          borderColor = AppColors.primaryBlue;
        }

        return GestureDetector(
          onTap: () => _selectOption(option.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: revealed && (isCorrect || isSelected) ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: revealed && isCorrect
                        ? const Color(0xFF16A34A)
                        : revealed && isSelected
                            ? const Color(0xFFDC2626)
                            : isSelected
                                ? AppColors.primaryBlue
                                : Colors.transparent,
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      option.id.toUpperCase(),
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (isSelected || (revealed && isCorrect)) ? Colors.white : textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.text,
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                    textDirection: TextDirection.rtl,
                  ),
                ),
                if (trailingIcon != null)
                  Icon(
                    trailingIcon,
                    color: isCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExplanationCard(bool isDark) {
    return AnimatedOpacity(
      opacity: _showExplanation ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEFCE8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE047)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: Color(0xFFCA8A04), size: 18),
                const SizedBox(width: 8),
                Text('الشرح', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFF92400E))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _current!.explanation!,
              style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF78350F), height: 1.6),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(bool isDark) {
    final answered = _answerState != AnswerState.unanswered;
    final hasExplanation = _current?.explanation != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          // Similar Question button
          if (answered)
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _loadingSimilar ? null : _loadSimilarQuestion,
                icon: _loadingSimilar
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text('مشابه', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (answered) const SizedBox(width: 8),

          // Explanation toggle
          if (answered && hasExplanation)
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showExplanation = !_showExplanation),
                icon: Icon(_showExplanation ? Icons.visibility_off_rounded : Icons.lightbulb_outline_rounded, size: 16),
                label: Text(_showExplanation ? 'إخفاء' : 'الشرح', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFCA8A04),
                  side: const BorderSide(color: Color(0xFFFDE047)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (answered && hasExplanation) const SizedBox(width: 8),

          // Next button
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: answered ? _nextQuestion : null,
              icon: Icon(
                _currentIndex == _questions.length - 1 ? Icons.flag_rounded : Icons.arrow_back_ios_new_rounded,
                size: 16,
              ),
              label: Text(
                _currentIndex == _questions.length - 1 ? 'إنهاء الجلسة' : 'السؤال التالي',
                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: answered ? AppColors.primaryBlue : Colors.grey[300],
                foregroundColor: answered ? Colors.white : Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: answered ? 2 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('لا توجد أسئلة', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'لا توجد أسئلة معتمدة للمواضيع المحددة. جرب اختيار مواضيع مختلفة.',
              style: GoogleFonts.cairo(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('العودة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }
}
