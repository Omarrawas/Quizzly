import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/exam_service.dart';
import 'package:quizzly/features/quiz/domain/services/exam_generator_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_session_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_book_mode_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_flashcards_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/active_recall_session_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/speed_mode_session_screen.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/auth/domain/services/activation_service.dart';
import 'package:provider/provider.dart';

class ExamsListScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const ExamsListScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<ExamsListScreen> createState() => _ExamsListScreenState();
}

class _ExamsListScreenState extends State<ExamsListScreen> {
  final ExamService _service = ExamService();
  final ExamGeneratorService _generator = ExamGeneratorService();
  final ActivationService _activationService = ActivationService();
  int _selectedFilter = 0;

  final List<String> _filters = ['الكل', 'الدورات الوزارية', 'بنك الأسئلة'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter chips
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemCount: _filters.length,
              itemBuilder: (context, i) => _FilterChip(
                label: _filters[i],
                isSelected: _selectedFilter == i,
                onTap: () => setState(() => _selectedFilter = i),
              ),
            ),
          ),
          // ── List
          Expanded(
            child: StreamBuilder<List<ExamConfig>>(
              stream: _service.streamExams(widget.subjectId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final allExams = snapshot.data ?? [];
                final filtered = _selectedFilter == 0
                    ? allExams
                    : _selectedFilter == 1
                        ? allExams.where((e) => e.type == ExamType.dora).toList()
                        : allExams.where((e) => e.type == ExamType.bank).toList();

                if (filtered.isEmpty) {
                  return const _EmptyState(message: 'لا توجد امتحانات متاحة حالياً');
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _ExamConfigTile(
                    config: filtered[index],
                    onTap: () => _handleExamTap(filtered[index]),
                  ),
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
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textPrimary, size: 20),
      ),
      title: Text(
        'الامتحانات - ${widget.subjectName}',
        style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
      centerTitle: true,
    );
  }

  Future<void> _handleExamTap(ExamConfig config) async {
    if (config.isFree) {
      _showExamOptions(config);
      return;
    }

    final userId = context.read<AuthService>().user?.uid;
    if (userId == null) return;

    // Check if subject is activated
    final hasAccess = await _activationService.hasExamAccess(userId, config.id!, widget.subjectId);
    if (hasAccess) {
      _showExamOptions(config);
    } else {
      _showActivationDialog(config);
    }
  }

  // ─── حوار خيارات بدء الامتحان ──────────────────────────────────────────
  void _showExamOptions(ExamConfig config) {
    int selectedMode = 1; // Default to Timed Exam

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          title: Text(
            config.title,
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر طريقة عرض أو بدء الاختبار المفضل لديك:',
                style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _ModeOption(
                index: 0,
                title: 'تصفح ككتاب',
                subtitle: 'عرض كافة الأسئلة مع الحلول والشرح',
                icon: Icons.menu_book_rounded,
                color: Colors.orange,
                isSelected: selectedMode == 0,
                onTap: () => setDialogState(() => selectedMode = 0),
              ),
              const SizedBox(height: 12),
              _ModeOption(
                index: 1,
                title: 'وضع "احفظني" (عالمي)',
                subtitle: 'أقوى وسيلة للحفظ عبر الاسترجاع النشط',
                icon: Icons.psychology_rounded,
                color: Colors.red,
                isSelected: selectedMode == 1,
                onTap: () => setDialogState(() => selectedMode = 1),
              ),
              const SizedBox(height: 12),
              _ModeOption(
                index: 2,
                title: 'امتحان مؤقت (أتمتة)',
                subtitle: 'اختبار تجريبي مع مؤقت تنازلي وحساب نقاط',
                icon: Icons.timer_rounded,
                color: AppColors.primaryBlue,
                isSelected: selectedMode == 2,
                onTap: () => setDialogState(() => selectedMode = 2),
              ),
              const SizedBox(height: 12),
              _ModeOption(
                index: 3,
                title: 'بطاقات ذكية',
                subtitle: 'مراجعة سريعة وحفظ عبر قلب البطاقات',
                icon: Icons.style_rounded,
                color: Colors.purple,
                isSelected: selectedMode == 3,
                onTap: () => setDialogState(() => selectedMode = 3),
              ),
              const SizedBox(height: 12),
              _ModeOption(
                index: 4,
                title: 'تحدي السرعة ⚡',
                subtitle: '10 ثوانٍ فقط لكل سؤال لإتقان السرعة',
                icon: Icons.bolt_rounded,
                color: Colors.amber,
                isSelected: selectedMode == 4,
                onTap: () => setDialogState(() => selectedMode = 4),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _launchExamMode(config, selectedMode);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('بدء الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchExamMode(ExamConfig config, int mode) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final questions = await _generator.generateExam(config);
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذراً، لا توجد أسئلة كافية لهذا الاختبار حالياً')),
        );
        return;
      }

      Widget screen;
      switch (mode) {
        case 0: // Book mode
          screen = ExamBookModeScreen(config: config, questions: questions);
          break;
        case 1: // Memory mode
          screen = ActiveRecallSessionScreen(config: config, questions: questions);
          break;
        case 3: // Flashcards
          screen = ExamFlashcardsScreen(config: config, questions: questions);
          break;
        case 4: // Speed mode
          screen = SpeedModeSessionScreen(config: config, questions: questions);
          break;
        default: // Exam mode
          screen = ExamSessionScreen(config: config, questions: questions);
      }

      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تجهيز الاختبار: $e')),
        );
      }
    }
  }

  Future<void> _showActivationDialog(ExamConfig config) async {
    final controller = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تفعيل المادة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'لتتمكن من الوصول لهذا الاختبار وجميع اختبارات مادة ${widget.subjectName}، يرجى إدخال كود تفعيل المادة.',
                style: GoogleFonts.cairo(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'أدخل الكود هنا...',
                  hintStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (controller.text.isEmpty) return;
                
                setDialogState(() => isLoading = true);
                final userId = context.read<AuthService>().user?.uid;
                final result = await _activationService.activateWithCode(
                  userId: userId!,
                  code: controller.text,
                  subjectId: widget.subjectId,
                );
                
                if (!mounted) return;
                setDialogState(() => isLoading = false);

                if (result['success']) {
                  if (!context.mounted) return;
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'], style: GoogleFonts.cairo())),
                  );
                  _showExamOptions(config);
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'], style: GoogleFonts.cairo()), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('تفعيل الآن', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                  Text(subtitle, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ExamConfigTile extends StatefulWidget {
  final ExamConfig config;
  final VoidCallback onTap;

  const _ExamConfigTile({required this.config, required this.onTap});

  @override
  State<_ExamConfigTile> createState() => _ExamConfigTileState();
}

class _ExamConfigTileState extends State<_ExamConfigTile> {
  int _correctCount = 0;
  int _wrongCount = 0;
  int _answeredCount = 0;
  bool _hasProgress = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('exam_book_state_${widget.config.id}');
    if (data != null) {
      try {
        final state = json.decode(data) as Map<String, dynamic>;
        int correct = 0;
        int wrong = 0;
        int answered = 0;
        if (state['answerStates'] != null) {
           final states = state['answerStates'] as Map<String, dynamic>;
           states.forEach((k, v) {
             final stateVal = v as String;
             if (stateVal == 'AnswerState.correct') {
               correct++;
             } else if (stateVal == 'AnswerState.wrong') {
               wrong++;
             }
           });
        }
        if (state['checkedQuestions'] != null) {
          answered = (state['checkedQuestions'] as List).length;
        }
        if (mounted) {
          setState(() {
            _correctCount = correct;
            _wrongCount = wrong;
            _answeredCount = answered;
            _hasProgress = answered > 0;
          });
        }
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDora = widget.config.type == ExamType.dora;
    final total = widget.config.totalQuestions;
    final unanswered = total > _answeredCount ? total - _answeredCount : 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: ListTile(
        onTap: widget.onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDora ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDora ? Icons.assignment_rounded : Icons.auto_awesome_rounded,
            color: isDora ? AppColors.primaryBlue : Colors.green,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.config.title,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            if (!widget.config.isFree)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 10, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'مدفوع',
                      style: GoogleFonts.cairo(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${widget.config.durationSeconds ~/ 60} دقيقة',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Icon(Icons.help_outline_rounded, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${widget.config.totalQuestions} سؤال',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (_hasProgress && total > 0) ...[
              const SizedBox(height: 12),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: Row(
                    children: [
                      if (_correctCount > 0)
                        Expanded(
                          flex: _correctCount,
                          child: Container(color: const Color(0xFF16A34A)),
                        ),
                      if (_wrongCount > 0)
                        Expanded(
                          flex: _wrongCount,
                          child: Container(color: const Color(0xFFDC2626)),
                        ),
                      if (unanswered > 0)
                        Expanded(
                          flex: unanswered,
                          child: Container(color: Colors.grey.shade300), // neutral
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تم حل $_answeredCount من $total',
                    style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary),
                  ),
                  Row(
                    children: [
                      Text('$_correctCount', style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('$_wrongCount', style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.grey),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primaryBlue : AppColors.borderLight),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.cairo(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
