import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/exam_service.dart';
import 'package:quizzly/features/quiz/domain/services/exam_generator_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_session_screen.dart';

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
                    onTap: () => _startExam(filtered[index]),
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

  Future<void> _startExam(ExamConfig config) async {
    // Show a quick loading dialog or overlay if needed
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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExamSessionScreen(
            config: config,
            questions: questions,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تجهيز الاختبار: $e')),
        );
      }
    }
  }
}

class _ExamConfigTile extends StatelessWidget {
  final ExamConfig config;
  final VoidCallback onTap;

  const _ExamConfigTile({required this.config, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDora = config.type == ExamType.dora;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: ListTile(
        onTap: onTap,
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
        title: Text(
          config.title,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.timer_outlined, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              '${config.durationSeconds ~/ 60} دقيقة',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Icon(Icons.help_outline_rounded, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              '${config.totalQuestions} سؤال',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
            ),
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
