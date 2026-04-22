import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

// ═══════════════════════════════════════════════════════
//  1. شريط الحالة العلوي (HUD)
// ═══════════════════════════════════════════════════════
class QuizHud extends StatelessWidget {
  final int current;
  final int total;
  final int correctCount;
  final int wrongCount;
  final Duration elapsed;
  final bool isTimerRunning;
  final VoidCallback onToggleTimer;

  const QuizHud({
    super.key,
    required this.current,
    required this.total,
    required this.correctCount,
    required this.wrongCount,
    required this.elapsed,
    required this.isTimerRunning,
    required this.onToggleTimer,
  });

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Timer
          GestureDetector(
            onTap: onToggleTimer,
            child: _HudPill(
              icon: isTimerRunning
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              label: _formatTime(elapsed),
              iconColor: AppColors.primaryBlue,
              bgColor: const Color(0xFFEFF6FF),
              labelColor: AppColors.primaryBlue,
            ),
          ),
          const Spacer(),
          // Wrong counter
          _HudPill(
            icon: Icons.close_rounded,
            label: '$wrongCount',
            iconColor: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
            labelColor: const Color(0xFFDC2626),
          ),
          const SizedBox(width: 6),
          // Correct counter
          _HudPill(
            icon: Icons.check_rounded,
            label: '$correctCount',
            iconColor: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
            labelColor: const Color(0xFF16A34A),
          ),
          const SizedBox(width: 6),
          // Progress counter
          _HudPill(
            icon: null,
            label: '$current/$total',
            iconColor: Colors.transparent,
            bgColor: AppColors.primaryBlue,
            labelColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final Color labelColor;

  const _HudPill({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.labelColor,
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
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  2. رأس الاختبار (Exam Header)
// ═══════════════════════════════════════════════════════
class QuizExamHeader extends StatelessWidget {
  final QuizExam exam;

  const QuizExamHeader({super.key, required this.exam});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exam.title,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          // Classification row
          Row(
            children: [
              const Icon(
                Icons.folder_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                'التصنيف: ${exam.classification}',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.edit_calendar_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                'آخر تعديل: ${exam.lastUpdated}',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Divider
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Filters + count row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'الفلاتر',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.insert_drive_file_rounded,
                size: 14,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 5),
              Text(
                '${exam.totalQuestions} أسئلة',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  3. بطاقة السؤال (Question Card)
// ═══════════════════════════════════════════════════════
class QuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final String? selectedOptionId;
  final AnswerState answerState;
  final bool showCorrect;
  final void Function(String optionId) onOptionSelected;

  const QuestionCard({
    super.key,
    required this.question,
    required this.selectedOptionId,
    required this.answerState,
    required this.showCorrect,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 3-dots menu row
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                _QuestionMenuButton(question: question),
                const Spacer(),
              ],
            ),
          ),
          // ── Question text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              '${question.number} - ${question.text}',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ),
          // ── Options
          if (question.options != null)
            ...question.options!.map(
              (option) => _OptionTile(
                option: option,
                isSelected: selectedOptionId == option.id,
                isCorrect: option.id == question.correctOptionId,
                answerState: answerState,
                showCorrect: showCorrect,
                onTap: () {
                  if (answerState == AnswerState.unanswered) {
                    onOptionSelected(option.id);
                  }
                },
              ),
            ),
          const SizedBox(height: 12),
          // ── Tag chip
          if (question.tagLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _TagChip(label: question.tagLabel!),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  خيار إجابة واحد
// ─────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final QuizOption option;
  final bool isSelected;
  final bool isCorrect;
  final AnswerState answerState;
  final bool showCorrect;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.isCorrect,
    required this.answerState,
    required this.showCorrect,
    required this.onTap,
  });

  Color get _bgColor {
    if (answerState == AnswerState.unanswered) {
      return isSelected ? const Color(0xFFEFF6FF) : Colors.transparent;
    }
    if (showCorrect && isCorrect) return const Color(0xFFF0FDF4);
    if (isSelected && answerState == AnswerState.wrong) {
      return const Color(0xFFFEF2F2);
    }
    if (isSelected && answerState == AnswerState.correct) {
      return const Color(0xFFF0FDF4);
    }
    return Colors.transparent;
  }

  Color get _borderColor {
    if (answerState == AnswerState.unanswered) {
      return isSelected ? AppColors.primaryBlue : AppColors.borderLight;
    }
    if (showCorrect && isCorrect) return const Color(0xFF16A34A);
    if (isSelected && answerState == AnswerState.wrong) {
      return const Color(0xFFDC2626);
    }
    if (isSelected && answerState == AnswerState.correct) {
      return const Color(0xFF16A34A);
    }
    return AppColors.borderLight;
  }

  Color get _radioColor {
    if (answerState == AnswerState.unanswered) {
      return isSelected ? AppColors.primaryBlue : AppColors.borderLight;
    }
    if (showCorrect && isCorrect) return const Color(0xFF16A34A);
    if (isSelected && answerState == AnswerState.wrong) {
      return const Color(0xFFDC2626);
    }
    if (isSelected && answerState == AnswerState.correct) {
      return const Color(0xFF16A34A);
    }
    return AppColors.borderLight;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _radioColor, width: 2),
                color: isSelected ? _radioColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            // Show result icon after reveal
            if (answerState != AnswerState.unanswered &&
                showCorrect &&
                isCorrect)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 18,
              ),
            if (isSelected && answerState == AnswerState.wrong)
              const Icon(
                Icons.cancel_rounded,
                color: Color(0xFFDC2626),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  وسم التصنيف (Tag Chip)
// ─────────────────────────────────────────
class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF7C3AED),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  4. شريط الأدوات السفلي للسؤال
// ═══════════════════════════════════════════════════════
class QuestionBottomBar extends StatelessWidget {
  final bool isFavorite;
  final bool isWrongMode; // true → shows X icon instead of check
  final VoidCallback onMenuTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback onCheckTap;

  const QuestionBottomBar({
    super.key,
    required this.isFavorite,
    required this.isWrongMode,
    required this.onMenuTap,
    required this.onFavoriteTap,
    required this.onCheckTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // ── Menu (3 dots)
          _BarIconButton(
            icon: Icons.more_horiz_rounded,
            color: AppColors.textSecondary,
            onTap: onMenuTap,
          ),
          const Spacer(),
          // ── Favorite
          _BarIconButton(
            icon: isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: isFavorite
                ? const Color(0xFFDC2626)
                : AppColors.textSecondary,
            onTap: onFavoriteTap,
          ),
          const SizedBox(width: 12),
          // ── Check / Wrong
          _BarIconButton(
            icon: isWrongMode
                ? Icons.cancel_rounded
                : Icons.check_circle_outline_rounded,
            color: isWrongMode
                ? const Color(0xFFDC2626)
                : AppColors.primaryBlue,
            onTap: onCheckTap,
          ),
        ],
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BarIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// ── 3-dots menu button per question
class _QuestionMenuButton extends StatelessWidget {
  final QuizQuestion question;
  const _QuestionMenuButton({required this.question});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: AppColors.textSecondary,
        size: 22,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        if (value == 'note') {
          showNoteDialog(context, question.number);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'note',
          child: Row(
            children: [
              const Icon(
                Icons.note_add_rounded,
                color: AppColors.primaryBlue,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text('إضافة ملاحظة', style: GoogleFonts.cairo(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                color: Color(0xFFDC2626),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text('إبلاغ عن خطأ', style: GoogleFonts.cairo(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  5. نافذة إضافة ملاحظة (Note Dialog)
// ═══════════════════════════════════════════════════════
void showNoteDialog(BuildContext context, int questionNumber) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'إضافة ملاحظة',
        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
        textAlign: TextAlign.center,
      ),
      content: TextField(
        controller: controller,
        maxLines: 4,
        style: GoogleFonts.cairo(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'ملاحظتك...',
          hintStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryBlue),
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'إلغاء',
            style: GoogleFonts.cairo(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text('حفظ', style: GoogleFonts.cairo()),
        ),
      ],
    ),
  );
}
