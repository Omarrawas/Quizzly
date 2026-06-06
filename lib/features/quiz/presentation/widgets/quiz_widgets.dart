import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:quizzly/features/settings/domain/services/settings_service.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // 1. Play/Pause button
          GestureDetector(
            onTap: onToggleTimer,
            child: Icon(
              isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          // 2. Timer Pill
          _HudPill(
            icon: Icons.timer_outlined,
            label: _formatTime(elapsed),
            color: const Color(0xFF2563EB),
            bgColor: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
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
            bgColor: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.15) : const Color(0xFFFEF2F2),
            onTap: onWrongTap,
          ),
          const SizedBox(width: 8),
          // Correct Pill
          _HudPill(
            icon: Icons.check_rounded,
            label: '$correctCount',
            color: const Color(0xFF16A34A),
            bgColor: isDark ? const Color(0xFF16A34A).withValues(alpha: 0.15) : const Color(0xFFF0FDF4),
            onTap: onCorrectTap,
          ),
          const SizedBox(width: 8),
          // Progress Pill
          _HudPill(
            icon: Icons.check_circle_rounded,
            label: '$current/$total',
            color: const Color(0xFF0891B2),
            bgColor: isDark ? const Color(0xFF0891B2).withValues(alpha: 0.15) : const Color(0xFFECFEFF),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
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
                color: isDark ? Colors.white : AppColors.textPrimary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: isDark ? Colors.white60 : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: isDark ? Colors.white60 : AppColors.textSecondary),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalColor = color ?? (isDark ? Colors.white60 : AppColors.textSecondary);
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
  final Set<String> selectedOptionIds;
  final AnswerState answerState;
  final bool showCorrect;
  final Function(String) onOptionSelected;
  final bool isInPrimaryList;
  final VoidCallback onListToggle;
  final VoidCallback onListLongPress;
  final IconData listIcon;
  final Color listColor;
  final String? note;
  final Function(String) onNoteChanged;
  final VoidCallback onCheckAnswer;
  final bool isChecked;
  final bool isSelected;
  final int? displayIndex;
  final void Function(String tag)? onTagTap;

  final String? essayAnswerValue;
  final Function(String)? onEssayChanged;

  const QuestionCard({
    super.key,
    required this.question,
    this.selectedOptionId,
    this.selectedOptionIds = const {},
    this.answerState = AnswerState.unanswered,
    this.showCorrect = false,
    required this.onOptionSelected,
    this.isInPrimaryList = false,
    required this.onListToggle,
    required this.onListLongPress,
    required this.listIcon,
    required this.listColor,
    this.note,
    required this.onNoteChanged,
    required this.onCheckAnswer,
    this.isChecked = false,
    this.isSelected = false,
    this.displayIndex,
    this.onTagTap,
    this.essayAnswerValue,
    this.onEssayChanged,
  });

  Color _getTagColor(String text, bool isDark) {
    final List<Color> darkColors = [
      const Color(0xFF38BDF8), // Sky Blue
      const Color(0xFFF472B6), // Pink/Rose
      const Color(0xFF34D399), // Emerald
      const Color(0xFFFBBF24), // Amber/Yellow
      const Color(0xFFA78BFA), // Lavender/Purple
      const Color(0xFFFB923C), // Orange
      const Color(0xFF2DD4BF), // Teal
      const Color(0xFFF87171), // Coral Red
    ];

    final List<Color> lightColors = [
      const Color(0xFF0284C7), // Deep Sky Blue
      const Color(0xFFDB2777), // Magenta/Rose
      const Color(0xFF059669), // Forest Emerald
      const Color(0xFFD97706), // Amber/Brown
      const Color(0xFF7C3AED), // Dark Purple
      const Color(0xFFEA580C), // Dark Orange
      const Color(0xFF0D9488), // Dark Teal
      const Color(0xFFDC2626), // Dark Red
    ];

    final int hash = text.hashCode.abs();
    final int index = hash % darkColors.length;
    return isDark ? darkColors[index] : lightColors[index];
  }

  void _showNoteDialog(BuildContext context) {
    final controller = TextEditingController(text: note);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('إضافة ملاحظة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white : Colors.black),
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'اكتب ملاحظتك هنا...',
            hintStyle: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
            ),
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

  void _showSavedNoteBottomSheet(BuildContext context) {
    int duration = 5;
    try {
      duration = Provider.of<SettingsService>(context, listen: false).notesDisplayDuration;
    } catch (_) {}

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => AutoCloseNoteBottomSheet(
        note: note ?? '',
        durationSeconds: duration,
        onEdit: () {
          Navigator.pop(context);
          _showNoteDialog(context);
        },
        onDelete: () {
          onNoteChanged('');
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم حذف الملاحظة بنجاح',
                style: GoogleFonts.cairo(),
                textAlign: TextAlign.right,
              ),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        },
      ),
    );
  }

  void _showTranslationDialog(BuildContext context, String translationText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.translate_rounded, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text('ترجمة السؤال', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        content: SingleChildScrollView(
          child: TexViewWidget(
            text: translationText,
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً', style: GoogleFonts.cairo(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.35) : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 2,
            )
          else
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        '${displayIndex ?? question.number} - ',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: TexViewWidget(
                          text: question.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                _QuestionMenuButton(question: question),
              ],
            ),
          ),
          
          if (question.translationText != null && question.translationText!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16, left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showTranslationDialog(context, question.translationText!),
                  icon: const Icon(Icons.g_translate_rounded, size: 16),
                  label: Text('ترجمة / توضيح', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF34D399),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
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
          if (question.options != null && (question.type == QuestionType.mcq || question.type == QuestionType.checkbox))
            ...question.options!.map(
              (option) {
                final bool isSelectedLocally = selectedOptionIds.contains(option.id) || selectedOptionId == option.id;
                return _OptionTile(
                  option: option,
                  isSelected: isSelectedLocally || (showCorrect && question.correctOptionIds.contains(option.id)),
                  isCorrect: question.correctOptionIds.contains(option.id),
                  answerState: answerState,
                  showCorrect: showCorrect,
                  isCheckbox: question.type == QuestionType.checkbox,
                  onTap: () {
                    if (answerState == AnswerState.unanswered) {
                       onOptionSelected(option.id);
                    }
                  },
                );
              },
            ),

          // Essay Input
          if (question.type == QuestionType.essay)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    maxLines: 6,
                    onChanged: onEssayChanged,
                    enabled: answerState == AnswerState.unanswered,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'اكتب إجابتك المقالية هنا...',
                      hintStyle: GoogleFonts.cairo(color: isDark ? Colors.white38 : Colors.grey),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  if (answerState != AnswerState.unanswered) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'الإجابة النموذجية:',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TexViewWidget(
                            text: question.essayAnswer ?? 'لا توجد إجابة نموذجية مسجلة.',
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Topic Info Row: Chapter/Lesson (e.g. الفصل الأول | الدرس الأول)
          if (question.topicNames != null && question.topicNames!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14, top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Builder(
                  builder: (context) {
                    final chapterText = question.topicNames!.first;
                    final color = _getTagColor(chapterText, isDark);
                    
                    final parts = chapterText.contains(' - ') 
                        ? chapterText.split(' - ') 
                        : chapterText.split(' | ');
                    
                    return GestureDetector(
                      onTap: () {
                        if (onTagTap != null) {
                          onTagTap!(chapterText);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
                        ),
                        child: parts.length >= 2
                            ? RichText(
                                text: TextSpan(
                                  style: GoogleFonts.cairo(color: color),
                                  children: [
                                    TextSpan(
                                      text: parts[1].trim(), // Lesson name (Large)
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' | ',
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: color.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    TextSpan(
                                      text: parts[0].trim(), // Chapter name (Small)
                                      style: GoogleFonts.cairo(
                                        fontSize: 10,
                                        fontWeight: FontWeight.normal,
                                        color: color.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Text(
                                chapterText,
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                      ),
                    );
                  }
                ),
              ),
            ),

          // Bottom Bar
          QuestionBottomBar(
            isInPrimaryList: isInPrimaryList,
            onListToggle: onListToggle,
            onListLongPress: onListLongPress,
            listIcon: listIcon,
            listColor: listColor,
            hasNote: note != null && note!.isNotEmpty,
            onNoteTap: () {
              if (note == null || note!.trim().isEmpty) {
                _showNoteDialog(context);
              } else {
                _showSavedNoteBottomSheet(context);
              }
            },
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
  final bool isCheckbox;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.isCorrect,
    required this.answerState,
    required this.showCorrect,
    this.isCheckbox = false,
    required this.onTap,
  });

  Color get _bgColor {
    if (showCorrect && isCorrect) return const Color(0xFF16A34A).withValues(alpha: 0.15);
    if (answerState == AnswerState.unanswered) {
      return isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.08) : Colors.transparent;
    }
    if (isSelected && answerState == AnswerState.wrong) {
      return const Color(0xFFDC2626).withValues(alpha: 0.15);
    }
    if (isSelected && answerState == AnswerState.correct) {
      return const Color(0xFF16A34A).withValues(alpha: 0.15);
    }
    return Colors.transparent;
  }

  Color get _radioColor {
    if (showCorrect && isCorrect) return const Color(0xFF16A34A);
    if (isSelected) return const Color(0xFF38BDF8);
    return Colors.grey.withValues(alpha: 0.3);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? _radioColor 
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
            width: 1.5,
          ),
        ),
        child: Row(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Expanded(
              child: Align(
                alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                child: TexViewWidget(
                  text: option.text,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (showCorrect && isCorrect) ...[
              SizedBox(width: isRtl ? 0 : 8),
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
              SizedBox(width: isRtl ? 8 : 0),
            ],
            if (isSelected && answerState == AnswerState.wrong) ...[
              SizedBox(width: isRtl ? 0 : 8),
              const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20),
              SizedBox(width: isRtl ? 8 : 0),
            ],
            const SizedBox(width: 12),
            // Radio circle or Checkbox square
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: isCheckbox ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isCheckbox ? BorderRadius.circular(6) : null,
                border: Border.all(color: _radioColor, width: 2),
                color: isSelected ? _radioColor : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      isCheckbox ? Icons.check_rounded : Icons.circle,
                      size: isCheckbox ? 14 : 8,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      icon: Icon(
        Icons.more_vert_rounded,
        color: isDark ? Colors.white60 : AppColors.textSecondary,
        size: 22,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        if (value == 'report') {
          showReportDialog(context, question);
        } else if (value == 'share') {
          _shareQuestion(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'share',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('مشاركة السؤال', style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white : Colors.black)),
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
              Text('الإبلاغ عن خطأ', style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white : Colors.black)),
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

  void _shareQuestion(BuildContext context) {
    if (question.id == null) return;
    
    // Using your Vercel domain for professional deep linking
    final String url = 'https://quizzly-tau.vercel.app/question?id=${question.id}&subjectId=${question.primaryTopicId ?? ""}';
    final String shareText = 'شاهد هذا السؤال على تطبيق كويزلي:\n\n${question.text}\n\nرابط السؤال:\n$url';
    
    // ignore: deprecated_member_use
    Share.share(shareText, subject: 'مشاركة سؤال من كويزلي');
  }
}

// ═══════════════════════════════════════════════════════
//  5. نافذة إضافة ملاحظة (Note Dialog)
// ═══════════════════════════════════════════════════════
void showNoteDialog(BuildContext context, int questionNumber) {
  final controller = TextEditingController();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'إضافة ملاحظة',
        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black),
        textAlign: TextAlign.center,
      ),
      content: TextField(
        controller: controller,
        maxLines: 4,
        style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: 'ملاحظتك...',
          hintStyle: GoogleFonts.cairo(color: isDark ? Colors.white38 : AppColors.textSecondary),
          filled: true,
          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
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
void showReportDialog(BuildContext context, QuizQuestion question) {
  final controller = TextEditingController();
  String selectedType = 'خطأ في الإجابة';

  final isDark = Theme.of(context).brightness == Brightness.dark;
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'الإبلاغ عن السؤال (#${question.number})',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل المشكلة',
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'اكتب تفاصيل المشكلة هنا...',
                      hintStyle: GoogleFonts.cairo(color: isDark ? Colors.white38 : AppColors.textSecondary),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'نوع المشكلة',
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black),
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
                      'questionId': question.id ?? question.number.toString(),
                      'questionNumber': question.number,
                      'questionText': question.text,
                      'tagLabel': question.tagLabel ?? '',
                      'topicNames': question.topicNames ?? [],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white24 : AppColors.textSecondary),
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
                  color: isSelected ? (isDark ? Colors.blue[300] : AppColors.primaryBlue) : (isDark ? Colors.white70 : AppColors.textPrimary),
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
//  نافذة شرح الإجابة (Auto-closing Explanation Bottom Sheet)
// ─────────────────────────────────────────
class AutoCloseExplanationBottomSheet extends StatefulWidget {
  final QuizQuestion question;
  final int durationSeconds;

  const AutoCloseExplanationBottomSheet({
    super.key,
    required this.question,
    required this.durationSeconds,
  });

  @override
  State<AutoCloseExplanationBottomSheet> createState() => _AutoCloseExplanationBottomSheetState();
}

class _AutoCloseExplanationBottomSheetState extends State<AutoCloseExplanationBottomSheet> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.durationSeconds != -1) {
      _timer = Timer(Duration(seconds: widget.durationSeconds), () {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: X button on the left, Title and Icon on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: isDark ? Colors.white60 : Colors.black54,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'توضيح الإجابة',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.question.explanationImageUrl != null && widget.question.explanationImageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        widget.question.explanationImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TexViewWidget(
                    text: widget.question.explanation ?? 'لا يوجد شرح متوفر لهذا السؤال حالياً.',
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showExplanationDialog(BuildContext context, QuizQuestion question) {
  int duration = 5;
  try {
    duration = Provider.of<SettingsService>(context, listen: false).explanationDisplayDuration;
  } catch (_) {}

  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (context) => AutoCloseExplanationBottomSheet(
      question: question,
      durationSeconds: duration,
    ),
  );
}

// ─────────────────────────────────────────
//  شريط عرض ملاحظة الطالب (Auto-closing Note Bottom Sheet)
// ─────────────────────────────────────────
class AutoCloseNoteBottomSheet extends StatefulWidget {
  final String note;
  final int durationSeconds;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AutoCloseNoteBottomSheet({
    super.key,
    required this.note,
    required this.durationSeconds,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<AutoCloseNoteBottomSheet> createState() => _AutoCloseNoteBottomSheetState();
}

class _AutoCloseNoteBottomSheetState extends State<AutoCloseNoteBottomSheet> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.durationSeconds != -1) {
      _timer = Timer(Duration(seconds: widget.durationSeconds), () {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: X button on the left, Title and Icon on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: isDark ? Colors.white60 : Colors.black54,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ملاحظتي',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.note_alt_outlined,
                    color: Color(0xFF0284C7),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Note content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  widget.note,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Actions: Delete and Edit
          Row(
            children: [
              // Delete Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Edit Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text('تعديل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
//  شريط الأدوات السفلي للسؤال
// ═══════════════════════════════════════════════════════
class QuestionBottomBar extends StatelessWidget {
  final bool isInPrimaryList;
  final VoidCallback onListToggle;
  final VoidCallback onListLongPress;
  final IconData listIcon;
  final Color listColor;
  final bool hasNote;
  final VoidCallback onNoteTap;
  final VoidCallback onCheckTap;
  final bool isChecked;
  final bool canCheck;
  final VoidCallback? onExplanationTap;

  const QuestionBottomBar({
    super.key,
    this.isInPrimaryList = false,
    required this.onListToggle,
    required this.onListLongPress,
    required this.listIcon,
    required this.listColor,
    this.hasNote = false,
    required this.onNoteTap,
    required this.onCheckTap,
    this.isChecked = false,
    this.canCheck = false,
    this.onExplanationTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Favorite/List Button
          _ActionButton(
            icon: listIcon,
            color: isInPrimaryList 
                ? (listIcon == Icons.favorite_rounded || listIcon == Icons.favorite_outline ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)) 
                : (isDark ? Colors.white60 : AppColors.textSecondary),
            customBgColor: isInPrimaryList 
                ? (listIcon == Icons.favorite_rounded || listIcon == Icons.favorite_outline 
                    ? const Color(0xFFEF4444).withValues(alpha: 0.15) 
                    : const Color(0xFFF59E0B).withValues(alpha: 0.15)) 
                : null,
            onTap: onListToggle,
            onLongPress: onListLongPress,
          ),
          
          // 2. Note Button
          _ActionButton(
            icon: hasNote ? Icons.note_alt_rounded : Icons.note_add_outlined,
            color: hasNote ? const Color(0xFF10B981) : (isDark ? Colors.white60 : AppColors.textSecondary),
            customBgColor: hasNote ? const Color(0xFF10B981).withValues(alpha: 0.15) : null,
            onTap: onNoteTap,
          ),
          
          // 3. Check Button
          _ActionButton(
            icon: isChecked ? Icons.check_circle_rounded : Icons.check_circle_outlined,
            color: isChecked 
                ? const Color(0xFF10B981) 
                : (canCheck ? const Color(0xFF38BDF8) : (isDark ? Colors.white24 : Colors.grey.shade400)),
            customBgColor: isChecked 
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : (canCheck ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : null),
            onTap: canCheck ? onCheckTap : null,
          ),

          // 4. Explanation Button
          if (onExplanationTap != null)
            _ActionButton(
              icon: Icons.lightbulb_rounded,
              color: const Color(0xFF34D399),
              customBgColor: const Color(0xFF10B981).withValues(alpha: 0.15),
              onTap: onExplanationTap,
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? customBgColor;

  const _ActionButton({
    required this.icon,
    this.onTap,
    this.onLongPress,
    this.color,
    this.customBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: customBgColor ?? (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color ?? (isDark ? Colors.white60 : AppColors.textSecondary),
            size: 22,
          ),
        ),
      ),
    );
  }
}
