import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';

class QuizScreen extends StatefulWidget {
  final QuizExam exam;
  final bool wrongAnswersMode;

  const QuizScreen({
    super.key,
    required this.exam,
    this.wrongAnswersMode = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // ── State ────────────────────────────────────────────
  int _currentIndex = 0;
  final Map<int, String> _selectedAnswers = {};
  final Map<int, AnswerState> _answerStates = {};
  final Set<int> _favorites = {};
  final Set<int> _revealed = {}; // which questions have been checked

  // Timer
  bool _timerRunning = true;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // Counters
  int get _correct =>
      _answerStates.values.where((s) => s == AnswerState.correct).length;
  int get _wrong =>
      _answerStates.values.where((s) => s == AnswerState.wrong).length;

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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timerRunning && mounted) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
  }

  void _toggleTimer() {
    HapticFeedback.selectionClick();
    setState(() => _timerRunning = !_timerRunning);
  }

  // ── Scroll controller ────────────────────────────────
  final ScrollController _scrollController = ScrollController();

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── HUD
          QuizHud(
            current: _currentIndex + 1,
            total: widget.exam.questions.length,
            correctCount: _correct,
            wrongCount: _wrong,
            elapsed: _elapsed,
            isTimerRunning: _timerRunning,
            onToggleTimer: _toggleTimer,
          ),
          const Divider(height: 1),
          // ── Scrollable content
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: widget.exam.questions.length + 1, // +1 for header
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      QuizExamHeader(exam: widget.exam),
                      const SizedBox(height: 4),
                    ],
                  );
                }
                final qIndex = i - 1;
                final question = widget.exam.questions[qIndex];
                final selected = _selectedAnswers[qIndex];
                final state = _answerStates[qIndex] ?? AnswerState.unanswered;
                final showCorrect = _revealed.contains(qIndex);

                return Column(
                  children: [
                    QuestionCard(
                      question: question,
                      selectedOptionId: selected,
                      answerState: state,
                      showCorrect: showCorrect,
                      onOptionSelected: (id) {
                        setState(() {
                          _currentIndex = qIndex;
                          _selectedAnswers[qIndex] = id;
                          _answerStates[qIndex] = AnswerState.unanswered;
                          _revealed.remove(qIndex);
                        });
                      },
                    ),
                    // Bottom action bar per question
                    QuestionBottomBar(
                      isFavorite: _favorites.contains(qIndex),
                      isWrongMode: widget.wrongAnswersMode,
                      onMenuTap: () => showNoteDialog(context, question.number),
                      onFavoriteTap: () {
                        setState(() {
                          if (_favorites.contains(qIndex)) {
                            _favorites.remove(qIndex);
                          } else {
                            _favorites.add(qIndex);
                          }
                        });
                      },
                      onCheckTap: () {
                        final sel = _selectedAnswers[qIndex];
                        if (sel == null) return;
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _revealed.add(qIndex);
                          final isCorrect =
                              question.correctOptionIds.contains(sel);
                          _answerStates[qIndex] = isCorrect
                              ? AnswerState.correct
                              : AnswerState.wrong;
                        });
                      },
                    ),
                    const _QuestionDivider(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.textPrimary,
          size: 20,
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.exam.title,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.search_rounded,
              color: AppColors.textSecondary, size: 24),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }
}

/// Divider between questions
class _QuestionDivider extends StatelessWidget {
  const _QuestionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: List.generate(
          40,
          (i) => Expanded(
            child: Container(
              height: 1,
              color: i.isEven ? AppColors.borderLight : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
