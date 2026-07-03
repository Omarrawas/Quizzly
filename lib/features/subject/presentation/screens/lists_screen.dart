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
import 'package:quizzly/features/quiz/presentation/screens/active_recall_session_screen.dart';

class ExamsListScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final bool isFree;

  const ExamsListScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.isFree = false,
  });

  @override
  State<ExamsListScreen> createState() => _ExamsListScreenState();
}

class _ExamsListScreenState extends State<ExamsListScreen> {
  final ExamService _service = ExamService();
  final ExamGeneratorService _generator = ExamGeneratorService();
  int _selectedFilter = 0;

  final List<String> _filters = ['الكل', 'الدورات الوزارية', 'الاختبارات'];

  int selectedPillar = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isDark),
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
                isDark: isDark,
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
                  return _EmptyState(message: 'لا توجد امتحانات متاحة حالياً', isDark: isDark);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _ExamConfigTile(
                    config: filtered[index],
                    onTap: () => _handleExamTap(filtered[index]),
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      elevation: 0,
      leading: Builder(
        builder: (context) {
          final isRtl = Directionality.of(context) == TextDirection.rtl;
          return IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded, 
              color: isDark ? Colors.white : AppColors.textPrimary, 
              size: 20
            ),
          );
        },
      ),
      title: Text(
        'الامتحانات - ${widget.subjectName}',
        style: GoogleFonts.cairo(
          fontSize: 18, 
          fontWeight: FontWeight.bold, 
          color: isDark ? Colors.white : AppColors.textPrimary
        ),
      ),
      centerTitle: true,
    );
  }

  Future<void> _handleExamTap(ExamConfig config) async {
    // If subject is free (activated) or the exam itself is free, show all options
    if (config.isFree || !widget.isFree) {
      _showExamOptions(config);
      return;
    }

    // For free users on a paid subject: 
    // We allow them to see the options (Pillars) but they will be restricted inside _showExamOptions
    _showExamOptions(config);
  }

// ─── حوار خيارات بدء الامتحان ──────────────────────────────────────────
  void _showExamOptions(ExamConfig config) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Column(
            children: [
              Text(
                config.title,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900, 
                  fontSize: 20, 
                  color: isDark ? Colors.white : AppColors.textPrimary
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'اختر ركيزة التدريب المناسبة لك',
                style: GoogleFonts.cairo(
                  fontSize: 12, 
                  color: isDark ? Colors.white70 : AppColors.textSecondary
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  _PillarOption(
                    title: 'التصفح والمراجعة',
                    subtitle: 'الاطلاع السريع على الأسئلة والأجوبة النموذجية',
                    icon: Icons.menu_book_rounded,
                    color: Colors.orange,
                    isSelected: selectedPillar == 0,
                    onTap: () => setDialogState(() => selectedPillar = 0),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _PillarOption(
                    title: 'الحفظ والتمكين',
                    subtitle: 'تثبيت المعلومات عبر المراجعة النشطة والبطاقات الذكية',
                    icon: Icons.psychology_rounded,
                    color: Colors.red,
                    isLocked: widget.isFree,
                    isSelected: selectedPillar == 1,
                    onTap: () {
                      if (widget.isFree) {
                        _showSubscriptionMsg();
                        return;
                      }
                      setDialogState(() => selectedPillar = 1);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _PillarOption(
                    title: 'المحاكاة والاختبار',
                    subtitle: 'تدريب على جو امتحان الحقيقي أو تحدي السرعة',
                    icon: Icons.timer_rounded,
                    color: AppColors.primaryBlue,
                    isLocked: widget.isFree,
                    isSelected: selectedPillar == 2,
                    onTap: () {
                      if (widget.isFree) {
                        _showSubscriptionMsg();
                        return;
                      }
                      setDialogState(() => selectedPillar = 2);
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _launchExamMode(config, selectedPillar);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('ابدأ التدريب الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionMsg() {
     ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('هذا النمط يتطلب اشتراكاً مفعلاً للمادة.', style: GoogleFonts.cairo()), backgroundColor: AppColors.primaryBlue),
    );
  }

  Future<void> _launchExamMode(ExamConfig config, int pillar) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (pillar == 2) {
      final String? choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'نوع الاختبار', 
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary
            ), 
            textAlign: TextAlign.center
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SubModeTile(
                title: 'امتحان شامل',
                subtitle: 'محاكاة لجو الامتحان الرسمي بمؤقت كلي',
                icon: Icons.timer_rounded,
                onTap: () => Navigator.pop(context, 'normal'),
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _SubModeTile(
                title: 'تحدي السرعة',
                subtitle: '10 ثوانٍ لكل سؤال لزيادة سرعة البديهة',
                icon: Icons.bolt_rounded,
                onTap: () => Navigator.pop(context, 'speed'),
                isDark: isDark,
              ),
            ],
          ),
        ),
      );

      if (choice == null) return;
      _startExamSession(config, choice == 'speed');
    } else {
      _startExamSession(config, false, pillar: pillar);
    }
  }

  Future<void> _startExamSession(ExamConfig config, bool isSpeed, {int pillar = 2}) async {
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
      if (pillar == 0) {
        screen = ExamBookModeScreen(
          config: config,
          questions: questions,
          isSubjectFree: widget.isFree,
        );
      } else if (pillar == 1) {
        screen = ActiveRecallSessionScreen(config: config, questions: questions);
      } else {
        screen = ExamSessionScreen(config: config, questions: questions, initialSpeedMode: isSpeed);
      }

      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

}

class _PillarOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLocked;
  final bool isDark;

  const _PillarOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.isLocked = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: isDark ? 0.15 : 0.05) 
              : (isLocked 
                  ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50]) 
                  : (isDark ? const Color(0xFF1E293B) : Colors.white)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? color 
                : (isLocked 
                    ? (isDark ? Colors.white10 : Colors.grey[200]!) 
                    : (isDark ? Colors.white10 : Colors.grey.shade100)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Opacity(
          opacity: isLocked ? 0.6 : 1.0,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLocked 
                      ? (isDark ? Colors.white10 : Colors.grey[200]) 
                      : color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isLocked ? Icons.lock_outline_rounded : icon, 
                  color: isLocked ? (isDark ? Colors.white38 : Colors.grey[600]) : color, 
                  size: 28
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isSelected ? color : (isDark ? Colors.white : AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      isLocked ? 'محتوى مدفوع للمشتركين' : subtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        height: 1.3,
                        color: isLocked 
                          ? Colors.red[300]
                          : (isSelected
                              ? color.withValues(alpha: 0.8)
                              : (isDark ? Colors.white38 : AppColors.textSecondary)),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamConfigTile extends StatefulWidget {
  final ExamConfig config;
  final VoidCallback onTap;
  final bool isDark;

  const _ExamConfigTile({required this.config, required this.onTap, required this.isDark});

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
    final data = prefs.getString('quiz_state_${widget.config.title}');
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
             if (stateVal == 'correct') {
               correct++;
             } else if (stateVal == 'wrong') {
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
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04), 
            blurRadius: 10
          )
        ],
      ),
      child: ListTile(
        onTap: widget.onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDora 
                ? (widget.isDark ? AppColors.primaryBlue.withValues(alpha: 0.1) : const Color(0xFFEFF6FF)) 
                : (widget.isDark ? Colors.green.withValues(alpha: 0.1) : const Color(0xFFF0FDF4)),
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
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold, 
                  fontSize: 14,
                  color: widget.isDark ? Colors.white : AppColors.textPrimary
                ),
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
                Icon(
                  Icons.timer_outlined, 
                  size: 12, 
                  color: widget.isDark ? Colors.white38 : AppColors.textSecondary
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.config.durationSeconds ~/ 60} دقيقة',
                  style: GoogleFonts.cairo(
                    fontSize: 11, 
                    color: widget.isDark ? Colors.white38 : AppColors.textSecondary
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.help_outline_rounded, 
                  size: 12, 
                  color: widget.isDark ? Colors.white38 : AppColors.textSecondary
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.config.totalQuestions} سؤال',
                  style: GoogleFonts.cairo(
                    fontSize: 11, 
                    color: widget.isDark ? Colors.white38 : AppColors.textSecondary
                  ),
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
                  color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
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
                          child: Container(
                            color: widget.isDark ? Colors.white10 : Colors.grey.shade300
                          ), // neutral
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
                    style: GoogleFonts.cairo(
                      fontSize: 10, 
                      color: widget.isDark ? Colors.white38 : AppColors.textSecondary
                    ),
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
  final bool isDark;

  const _FilterChip({
    required this.label, 
    required this.isSelected, 
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryBlue 
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? AppColors.primaryBlue 
                : (isDark ? Colors.white10 : AppColors.borderLight)
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white60 : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final bool isDark;
  const _EmptyState({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_late_rounded, 
            size: 64, 
            color: isDark ? Colors.white10 : Colors.grey[300]
          ),
          const SizedBox(height: 16),
          Text(
            message, 
            style: GoogleFonts.cairo(
              color: isDark ? Colors.white38 : AppColors.textSecondary
            )
          ),
        ],
      ),
    );
  }
}

class _SubModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _SubModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryBlue),
      ),
      title: Text(
        title, 
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold, 
          fontSize: 14,
          color: isDark ? Colors.white : AppColors.textPrimary
        )
      ),
      subtitle: Text(
        subtitle, 
        style: GoogleFonts.cairo(
          fontSize: 10,
          color: isDark ? Colors.white38 : AppColors.textSecondary
        )
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
    );
  }
}
