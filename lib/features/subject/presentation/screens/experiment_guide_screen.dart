import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';

class ExperimentGuideScreen extends StatefulWidget {
  final PracticalItem item;

  const ExperimentGuideScreen({super.key, required this.item});

  @override
  State<ExperimentGuideScreen> createState() => _ExperimentGuideScreenState();
}

class _ExperimentGuideScreenState extends State<ExperimentGuideScreen> {
  final Set<int> _completedSteps = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = widget.item.steps ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'دليل التجربة',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
        ),
        leading: Builder(
          builder: (context) {
            final isRtl = Directionality.of(context) == TextDirection.rtl;
            return IconButton(
              icon: Icon(
                isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : AppColors.textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExperimentHeader(isDark),
            const SizedBox(height: 24),
            Text(
              'خطوات العمل',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(steps.length, (index) => _buildStepCard(index, steps[index], isDark)),
            const SizedBox(height: 32),
            _buildCompletionStatus(steps.length, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildExperimentHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'كيمياء حيوية',
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.item.title,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.item.description,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int index, String stepText, bool isDark) {
    final isCompleted = _completedSteps.contains(index);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isCompleted) {
            _completedSteps.remove(index);
          } else {
            _completedSteps.add(index);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted 
                ? const Color(0xFF10B981) 
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${index + 1}',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                stepText,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted 
                      ? (isDark ? Colors.white38 : Colors.grey)
                      : (isDark ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionStatus(int totalSteps, bool isDark) {
    final progress = totalSteps > 0 ? _completedSteps.length / totalSteps : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تقدم العمل',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white,
              color: const Color(0xFF10B981),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
