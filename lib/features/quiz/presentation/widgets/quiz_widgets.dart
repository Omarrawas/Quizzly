import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final Widget? additionalAction;

  const QuizHud({
    super.key,
    required this.current,
    required this.total,
    required this.correctCount,
    required this.wrongCount,
    required this.elapsed,
    required this.isTimerRunning,
    required this.onToggleTimer,
    this.additionalAction,
  });

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: onToggleTimer,
            child: Icon(
              isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          if (additionalAction != null) ...[
            additionalAction!,
            const SizedBox(width: 8),
          ],
          // Timer Pill
          _HudPill(
            icon: Icons.timer_outlined,
            label: _formatTime(elapsed),
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
          const Spacer(),
          // Wrong Pill
          _HudPill(
            icon: Icons.close_rounded,
            label: '$wrongCount',
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
          ),
          const SizedBox(width: 8),
          // Correct Pill
          _HudPill(
            icon: Icons.check_rounded,
            label: '$correctCount',
            color: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
          ),
          const SizedBox(width: 8),
          // Progress Pill
          _HudPill(
            icon: Icons.check_circle_rounded,
            label: '$current/$total',
            color: const Color(0xFF0891B2),
            bgColor: const Color(0xFFECFEFF),
          ),
        ],
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _HudPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير متوفر';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              exam.title,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 16),
          // Classification row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _HeaderPill(
                icon: Icons.access_time_rounded,
                label: 'آخر تعديل: ${_formatDate(exam.lastUpdated)}',
              ),
              const SizedBox(width: 8),
              _HeaderPill(
                icon: Icons.folder_open_rounded,
                label: 'التصنيف: ${exam.classification}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bottom row: Filters and Question count
          Row(
            children: [
              _IconActionChip(
                icon: Icons.filter_list_rounded,
                label: 'الفلاتر',
                onTap: () {},
              ),
              const Spacer(),
              _IconActionChip(
                icon: Icons.description_outlined,
                label: '${exam.totalQuestions} أسئلة',
                color: AppColors.primaryBlue,
                onTap: null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _IconActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _IconActionChip({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final finalColor = color ?? AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTap != null) ...[
              Icon(icon, size: 18, color: finalColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: finalColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: finalColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 18, color: finalColor),
            ],
          ],
        ),
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
  
  // New callbacks for bottom actions
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onCheck;
  final VoidCallback? onAddNote;

  const QuestionCard({
    super.key,
    required this.question,
    required this.selectedOptionId,
    required this.answerState,
    required this.showCorrect,
    required this.onOptionSelected,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onCheck,
    this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row with 3 dots and Question text
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuestionMenuButton(question: question),
                const Spacer(),
                Expanded(
                  child: Text(
                    '${question.number} - ${question.text}',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 12),
          // ── Options
          if (question.options != null)
            ...question.options!.map(
              (option) => _OptionTile(
                option: option,
                isSelected: selectedOptionId == option.id || (showCorrect && question.correctOptionIds.contains(option.id)),
                isCorrect: question.correctOptionIds.contains(option.id),
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
          // ── Tag chip (Aligned right)
          if (question.tagLabel != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 12),
                child: _TagChip(label: question.tagLabel!),
              ),
            ),
          // ── Bottom Toolbar
          QuestionBottomBar(
            isFavorite: isFavorite,
            isRevealed: showCorrect,
            onCheck: onCheck ?? () {},
            onFavorite: onFavoriteToggle ?? () {},
            onAddNote: onAddNote ?? () {
              showNoteDialog(context, question.number);
            },
          ),
          const SizedBox(height: 12),
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
    if (showCorrect && isCorrect) return const Color(0xFFF0FDF4);
    if (answerState == AnswerState.unanswered) {
      return isSelected ? const Color(0xFFF8FAFC) : Colors.transparent;
    }
    if (isSelected && answerState == AnswerState.wrong) {
      return const Color(0xFFFEF2F2);
    }
    if (isSelected && answerState == AnswerState.correct) {
      return const Color(0xFFF0FDF4);
    }
    return Colors.transparent;
  }

  Color get _radioColor {
    if (showCorrect && isCorrect) return const Color(0xFF16A34A);
    if (isSelected) return AppColors.primaryBlue;
    return AppColors.borderLight;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _radioColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (showCorrect && isCorrect)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
            if (isSelected && answerState == AnswerState.wrong)
              const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20),
            const Spacer(),
            Expanded(
              child: Text(
                option.text,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
            // Radio circle on the right
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _radioColor, width: 2),
                color: isSelected ? _radioColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
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
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFE11D48),
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
  final bool isRevealed;
  final VoidCallback onCheck;
  final VoidCallback onFavorite;
  final VoidCallback onAddNote;

  const QuestionBottomBar({
    super.key,
    this.isFavorite = false,
    this.isRevealed = false,
    required this.onCheck,
    required this.onFavorite,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CircleAction(
            icon: isRevealed ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
            color: isRevealed ? const Color(0xFF16A34A) : AppColors.textPrimary,
            onTap: onCheck,
          ),
          _CircleAction(
            icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite ? const Color(0xFFE11D48) : AppColors.textPrimary,
            onTap: onFavorite,
          ),
          _CircleAction(
            icon: Icons.note_add_outlined,
            onTap: onAddNote,
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _CircleAction({required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final finalColor = color ?? AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: finalColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: finalColor, size: 24),
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
        if (value == 'report') {
          showReportDialog(context, question.number);
        } else if (value == 'share') {
          // TODO: Implement share
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'share',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('مشاركة السؤال', style: GoogleFonts.cairo(fontSize: 14)),
              const SizedBox(width: 10),
              const Icon(
                Icons.share_rounded,
                color: AppColors.primaryBlue,
                size: 18,
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'report',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('الإبلاغ عن خطأ', style: GoogleFonts.cairo(fontSize: 14)),
              const SizedBox(width: 10),
              const Icon(
                Icons.flag_rounded,
                color: Color(0xFFDC2626),
                size: 18,
              ),
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
// ═══════════════════════════════════════════════════════
//  6. نافذة الإبلاغ عن سؤال (Report Dialog)
// ═══════════════════════════════════════════════════════
void showReportDialog(BuildContext context, int questionNumber) {
  final controller = TextEditingController();
  String selectedType = 'خطأ في الإجابة';

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'الإبلاغ عن السؤال (#$questionNumber)',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل المشكلة',
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'اكتب تفاصيل المشكلة هنا...',
                      hintStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'نوع المشكلة',
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  _ReportOption(
                    label: 'خطأ في الإجابة',
                    value: 'خطأ في الإجابة',
                    groupValue: selectedType,
                    onChanged: (v) => setState(() => selectedType = v!),
                  ),
                  _ReportOption(
                    label: 'خطأ إملائي',
                    value: 'خطأ إملائي',
                    groupValue: selectedType,
                    onChanged: (v) => setState(() => selectedType = v!),
                  ),
                  _ReportOption(
                    label: 'استفسار عن السؤال',
                    value: 'استفسار عن السؤال',
                    groupValue: selectedType,
                    onChanged: (v) => setState(() => selectedType = v!),
                  ),
                ],
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
                onPressed: () async {
                  final details = controller.text.trim();
                  final user = FirebaseAuth.instance.currentUser;

                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    await FirebaseFirestore.instance.collection('question_reports').add({
                      'questionId': questionNumber.toString(),
                      'questionText': '', // Ideally pass question text too
                      'details': details,
                      'type': selectedType,
                      'userId': user?.uid ?? 'anonymous',
                      'userEmail': user?.email ?? 'anonymous',
                      'createdAt': FieldValue.serverTimestamp(),
                      'status': 'pending',
                    });

                    if (context.mounted) {
                      Navigator.pop(context); // Pop loading
                      Navigator.pop(context); // Pop report dialog
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم إرسال بلاغك بنجاح، شكراً لك!',
                            style: GoogleFonts.cairo(),
                            textAlign: TextAlign.right,
                          ),
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Pop loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'حدث خطأ أثناء إرسال البلاغ. حاول مجدداً.',
                            style: GoogleFonts.cairo(),
                            textAlign: TextAlign.right,
                          ),
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                ),
                child: Text('إرسال', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ReportOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _ReportOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 10 : 0,
                    height: isSelected ? 10 : 0,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
