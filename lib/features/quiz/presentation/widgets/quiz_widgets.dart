import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/core/widgets/smart_text.dart';

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
  final VoidCallback? onCorrectTap;
  final VoidCallback? onWrongTap;

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
    this.onCorrectTap,
    this.onWrongTap,
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
          // 1. Play/Pause button
          GestureDetector(
            onTap: onToggleTimer,
            child: Icon(
              isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          // 2. Timer Pill
          _HudPill(
            icon: Icons.timer_outlined,
            label: _formatTime(elapsed),
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
          // 3. Filters button (additionalAction)
          if (additionalAction != null) ...[
            const SizedBox(width: 12),
            additionalAction!,
          ],
          const Spacer(),
          // Wrong Pill
          _HudPill(
            icon: Icons.close_rounded,
            label: '$wrongCount',
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
            onTap: onWrongTap,
          ),
          const SizedBox(width: 8),
          // Correct Pill
          _HudPill(
            icon: Icons.check_rounded,
            label: '$correctCount',
            color: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
            onTap: onCorrectTap,
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
  final VoidCallback? onTap;

  const _HudPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _HeaderPill(
                icon: Icons.folder_open_rounded,
                label: exam.type == ExamType.dora ? 'دورة' : 'بنك',
              ),
              const SizedBox(width: 8),
              _HeaderPill(
                icon: Icons.access_time_rounded,
                label: 'آخر تعديل: ${_formatDate(exam.lastUpdated ?? exam.createdAt)}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bottom row: Filters and Question count
          Row(
            children: [
              _IconActionChip(
                icon: Icons.description_outlined,
                label: '${exam.totalQuestions} أسئلة',
                color: AppColors.primaryBlue,
                onTap: null,
              ),
              const Spacer(),
              _IconActionChip(
                icon: Icons.filter_list_rounded,
                label: 'الفلاتر',
                onTap: () {},
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
  final Function(String) onOptionSelected;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final String? note;
  final Function(String) onNoteChanged;
  final VoidCallback onCheckAnswer;
  final bool isChecked;
  final bool isSelected;
  final int? displayIndex;
  final void Function(String tag)? onTagTap;

  const QuestionCard({
    super.key,
    required this.question,
    this.selectedOptionId,
    this.answerState = AnswerState.unanswered,
    this.showCorrect = false,
    required this.onOptionSelected,
    this.isFavorite = false,
    required this.onFavoriteToggle,
    this.note,
    required this.onNoteChanged,
    required this.onCheckAnswer,
    this.isChecked = false,
    this.isSelected = false,
    this.displayIndex,
    this.onTagTap,
  });

  void _showNoteDialog(BuildContext context) {
    final controller = TextEditingController(text: note);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة ملاحظة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'اكتب ملاحظتك هنا...',
            hintStyle: GoogleFonts.cairo(fontSize: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              onNoteChanged(controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('حفظ', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Question Number and Menu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SmartText(
                    text: '${displayIndex ?? question.number} - ${question.text}',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                _QuestionMenuButton(question: question),
              ],
            ),
          ),
          
          // Question Image (if exists)
          if (question.imageUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  question.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),

          // Options List
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

          const SizedBox(height: 16),

          // Tag Labels (examTags + tagLabel)
          if (question.examTags.isNotEmpty || question.tagLabel != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (question.tagLabel != null && !question.examTags.contains(question.tagLabel))
                      _TagChip(
                        label: question.tagLabel!,
                        onTap: onTagTap != null ? () => onTagTap!(question.tagLabel!) : null,
                      ),
                    for (final tag in question.examTags)
                      _TagChip(
                        label: tag,
                        onTap: onTagTap != null ? () => onTagTap!(tag) : null,
                      ),
                  ],
                ),
              ),
            ),

          // Bottom Bar
          QuestionBottomBar(
            isFavorite: isFavorite,
            onFavoriteToggle: onFavoriteToggle,
            hasNote: note != null && note!.isNotEmpty,
            onNoteTap: () => _showNoteDialog(context),
            onCheckTap: onCheckAnswer,
            isChecked: isChecked,
            canCheck: isSelected && !isChecked,
            onExplanationTap: (question.explanation != null && question.explanation!.isNotEmpty) ||
                              (question.explanationImageUrl != null && question.explanationImageUrl!.isNotEmpty)
                ? () => showExplanationDialog(context, question)
                : null,
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
            const SizedBox(width: 12),
            Expanded(
              child: SmartText(
                text: option.text,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            if (showCorrect && isCorrect) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
            ],
            if (isSelected && answerState == AnswerState.wrong) ...[
              const SizedBox(width: 8),
              const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20),
            ],
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
  final VoidCallback? onTap;
  const _TagChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ميزة المشاركة ستكون متوفرة قريباً',
                style: GoogleFonts.cairo(),
                textAlign: TextAlign.right,
              ),
              backgroundColor: AppColors.primaryBlue,
            ),
          );
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

// ─────────────────────────────────────────
//  نافذة شرح الإجابة
// ─────────────────────────────────────────
void showExplanationDialog(BuildContext context, QuizQuestion question) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'توضيح الإجابة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 24),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (question.explanationImageUrl != null && question.explanationImageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  question.explanationImageUrl!,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            SmartText(
              text: question.explanation ?? 'لا يوجد شرح متوفر لهذا السؤال حالياً.',
              style: GoogleFonts.cairo(
                fontSize: 15,
                height: 1.8,
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            'فهمت ذلك',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2563EB),
            ),
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════
//  شريط الأدوات السفلي للسؤال
// ═══════════════════════════════════════════════════════
class QuestionBottomBar extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool hasNote;
  final VoidCallback onNoteTap;
  final VoidCallback onCheckTap;
  final bool isChecked;
  final bool canCheck;
  final VoidCallback? onExplanationTap;

  const QuestionBottomBar({
    super.key,
    this.isFavorite = false,
    required this.onFavoriteToggle,
    this.hasNote = false,
    required this.onNoteTap,
    required this.onCheckTap,
    this.isChecked = false,
    this.canCheck = false,
    this.onExplanationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (onExplanationTap != null)
            _ActionButton(
              icon: Icons.lightbulb_rounded,
              color: Colors.amber.shade600,
              onTap: onExplanationTap,
            ),
          _ActionButton(
            icon: hasNote ? Icons.note_alt_rounded : Icons.note_add_outlined,
            color: hasNote ? const Color(0xFF16A34A) : null,
            onTap: onNoteTap,
          ),
          _ActionButton(
            icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite ? Colors.red : null,
            onTap: onFavoriteToggle,
          ),
          _ActionButton(
            icon: isChecked ? Icons.check_circle_rounded : Icons.check_circle_outlined,
            color: isChecked ? const Color(0xFF16A34A) : (canCheck ? const Color(0xFF2563EB) : Colors.grey.shade400),
            onTap: canCheck ? onCheckTap : null,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: color ?? AppColors.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}
