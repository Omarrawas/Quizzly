import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';

class OralInterviewScreen extends StatefulWidget {
  final PracticalItem item;

  const OralInterviewScreen({super.key, required this.item});

  @override
  State<OralInterviewScreen> createState() => _OralInterviewScreenState();
}

class _OralInterviewScreenState extends State<OralInterviewScreen> {
  final Set<int> _revealedAnswers = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final questions = widget.item.oralQuestions ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C14) : const Color(0xFFE5E2DA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131A26) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'بنك المقابلات',
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
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          return _buildQuestionCard(index, questions[index], isDark);
        },
      ),
    );
  }

  Widget _buildQuestionCard(int index, OralQuestion q, bool isDark) {
    final isRevealed = _revealedAnswers.contains(index);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A26) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isRevealed) {
                _revealedAnswers.remove(index);
              } else {
                _revealedAnswers.add(index);
              }
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: Color(0xFF7C3AED), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        q.question,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isRevealed) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          q.answer,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'اضغط لإظهار الإجابة النموذجية',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
