import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';

/// شاشة الإجابات الخاطئة - نسخة خاصة من QuizScreen
class WrongAnswersScreen extends StatefulWidget {
  final String subjectName;

  const WrongAnswersScreen({
    super.key,
    this.subjectName = 'الكيمياء',
  });

  @override
  State<WrongAnswersScreen> createState() => _WrongAnswersScreenState();
}

class _WrongAnswersScreenState extends State<WrongAnswersScreen> {
  // Mock: الأسئلة التي أجاب عليها المستخدم خطأً
  final List<QuizQuestion> _wrongQuestions = mockQuizExam.questions;

  // حالة التصحيح
  final Map<int, String> _selectedAnswers = {};
  final Map<int, AnswerState> _answerStates = {};
  final Map<int, bool> _revealed = {};
  bool _showAllAnswers = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Top stats bar
          _buildStatsBar(),
          const Divider(height: 1),
          // ── Filter row
          _buildFilterRow(),
          // ── Questions
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _wrongQuestions.length,
              itemBuilder: (context, index) {
                final question = _wrongQuestions[index];
                final selected = _selectedAnswers[index];
                final state =
                    _answerStates[index] ?? AnswerState.unanswered;
                final showCorrect =
                    _revealed[index] ?? _showAllAnswers;

                return Column(
                  children: [
                    // Exam breadcrumb
                    _ExamBreadcrumb(examTitle: mockQuizExam.title),
                    QuestionCard(
                      question: question,
                      selectedOptionId: selected,
                      answerState: state,
                      showCorrect: showCorrect,
                      onOptionSelected: (id) {
                        setState(() {
                          _selectedAnswers[index] = id;
                          _answerStates[index] = AnswerState.unanswered;
                          _revealed[index] = false;
                        });
                      },
                    ),
                    // Wrong mode bottom bar
                    _WrongModeBar(
                      onReset: () {
                        setState(() {
                          _selectedAnswers.remove(index);
                          _answerStates.remove(index);
                          _revealed[index] = false;
                        });
                      },
                      onCorrectAll: () {
                        setState(() => _showAllAnswers = true);
                      },
                      onMarkCorrect: () {
                        setState(() {
                          final sel = _selectedAnswers[index];
                          if (sel != null) {
                            _revealed[index] = true;
                            final isCorrect =
                                question.correctOptionIds.contains(sel);
                            _answerStates[index] = isCorrect
                                ? AnswerState.correct
                                : AnswerState.wrong;
                          }
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
      title: Text(
        'الإجابات الخاطئة',
        style: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          // Timer placeholder (static in wrong mode)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_circle_filled_rounded,
                    size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 4),
                Text(
                  '00:00',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Wrong: 0
          _StatPill(
            icon: Icons.close_rounded,
            label: '0',
            iconColor: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
          ),
          const SizedBox(width: 6),
          // Correct: 0
          _StatPill(
            icon: Icons.check_rounded,
            label: '0',
            iconColor: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
          ),
          const SizedBox(width: 6),
          // Total
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '1/${_wrongQuestions.length}',
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded,
              size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 5),
          Text(
            '${_wrongQuestions.length} سؤال',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          const Spacer(),
          // Sort filter
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'حسب التاريخ',
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Filters
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'الفلاتر',
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Wrong Mode Bottom Action Bar
// ─────────────────────────────────────────
class _WrongModeBar extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onCorrectAll;
  final VoidCallback onMarkCorrect;

  const _WrongModeBar({
    required this.onReset,
    required this.onCorrectAll,
    required this.onMarkCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Reset answers
          _ActionBtn(
            icon: Icons.refresh_rounded,
            label: 'تصغير الإجابات',
            color: AppColors.primaryBlue,
            bg: const Color(0xFFEFF6FF),
            onTap: onReset,
          ),
          const Spacer(),
          // Correct all
          _ActionBtn(
            icon: Icons.done_all_rounded,
            label: 'تصحيح الكل',
            color: const Color(0xFF16A34A),
            bg: const Color(0xFFF0FDF4),
            onTap: onCorrectAll,
          ),
          const Spacer(),
          // Wrong mark
          GestureDetector(
            onTap: onMarkCorrect,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Exam Breadcrumb (source label per question)
// ─────────────────────────────────────────
class _ExamBreadcrumb extends StatelessWidget {
  final String examTitle;
  const _ExamBreadcrumb({required this.examTitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_ios_rounded,
                size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              examTitle,
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Stat Pill (reusable in stats bar)
// ─────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared divider (copied locally to avoid circular imports)
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
