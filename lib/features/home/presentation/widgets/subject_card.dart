import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/features/quiz/domain/services/exam_service.dart';

class SubjectCard extends StatefulWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onTap;
  final int index;
  final bool showDragHandle;
  final String userId;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
    required this.userId,
    this.index = 0,
    this.showDragHandle = false,
  });

  @override
  State<SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<SubjectCard> {
  final ExamService _examService = ExamService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.subject['name'] ?? 'مادة غير معروفة';
    final status = widget.subject['status'] ?? 'active';
    final subjectId = widget.subject['id'] as String? ?? '';

    final university = widget.subject['universityName'] ?? 'الجامعة غير محددة';
    final college = widget.subject['collegeName'] ?? 'الكلية غير محددة';
    final department = widget.subject['departmentName'] ?? 'القسم غير محدد';
    final year = widget.subject['yearName'] ?? 'السنة الدراسية غير محددة';
    final semester = widget.subject['semesterName'] ?? 'الفصل غير محدد';

    final vibrantColors = [
      (const Color(0xFF4F46E5), const Color(0xFF818CF8)), // Indigo
      (const Color(0xFFE11D48), const Color(0xFFFB7185)), // Rose
      (const Color(0xFF0D9488), const Color(0xFF2DD4BF)), // Teal
      (const Color(0xFFD97706), const Color(0xFFFBBF24)), // Amber
      (const Color(0xFF0284C7), const Color(0xFF38BDF8)), // Sky
      (const Color(0xFF7C3AED), const Color(0xFFA78BFA)), // Violet
    ];
    final (colorMain, colorLight) =
        vibrantColors[widget.index % vibrantColors.length];

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorMain, colorLight],
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : colorMain).withValues(
                alpha: isDark ? 0.4 : 0.3,
              ),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon, Status, and Action Arrow
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                if (status == 'active' || status == 'demo')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          status == 'demo' ? 'ديمو' : 'مفعّل',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (widget.showDragHandle)
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '=',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.drag_handle_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Subject Name & Code
            Text(
              name,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Builder(
                builder: (context) {
                  final activationType = widget.subject['activationType'];
                  if (activationType == 'code') {
                    return Text(
                      'تفعيل بواسطة كود',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }

                  final price =
                      (widget.subject['paidPrice'] as num?)?.toDouble() ??
                      (widget.subject['price'] as num?)?.toDouble() ??
                      0.0;
                  final discount =
                      (widget.subject['discount'] as num?)?.toDouble() ?? 0.0;

                  if (activationType == 'free' || price <= 0) {
                    return Text(
                      'تفعيل مجاني',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }

                  final finalPrice = discount > 0
                      ? (price * (1 - discount / 100))
                      : price;

                  return Text(
                    'تفعيل بمبلغ ${finalPrice.toStringAsFixed(0)} ليرة',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 16),

            // Detailed Information Rows
            _buildInfoRow(
              Icons.account_balance_rounded,
              '$university  •  $college',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.category_rounded, '$department  •  $year'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_month_rounded, semester),

            // ── Stats & Exam Data Section ──
            if (subjectId.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 16),
              _buildSubjectStats(subjectId, isDark, colorMain),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectStats(String subjectId, bool isDark, Color colorMain) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _examService.streamRecentAttemptsBySubject(
        widget.userId,
        subjectId,
        limit: 3,
      ),
      builder: (context, snapshot) {
        final attempts = snapshot.data ?? [];

        // If no data yet and still loading, show skeleton
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCompactLoading(isDark);
        }

        // Show topics progress (fetch topics count from subject data)
        final progress = widget.subject['progress'];
        final hasProgress = progress != null && progress is num && progress > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar if available
            if (hasProgress) ...[
              _buildProgressRow(progress.toDouble(), isDark),
              const SizedBox(height: 12),
            ],

            // Latest exam attempt
            if (attempts.isNotEmpty) ...[
              _buildLatestAttempt(attempts.first, isDark),
            ] else ...[
              _buildNoExamsYet(isDark),
            ],
          ],
        );
      },
    );
  }

  Widget _buildProgressRow(double progress, bool isDark) {
    final percentage = (progress * 100).clamp(0, 100).toInt();
    return Row(
      children: [
        Icon(
          Icons.trending_up_rounded,
          color: Colors.white.withValues(alpha: 0.8),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$percentage%',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'تقدم الدراسة',
                    style: GoogleFonts.cairo(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLatestAttempt(Map<String, dynamic> attempt, bool isDark) {
    final totalQuestions = attempt['totalQuestions'] ?? 0;
    final correctCount = attempt['correctCount'] ?? 0;
    final score = (attempt['score'] as num?)?.toDouble() ?? 0.0;

    Color scoreColor;
    String scoreLabel;
    if (score >= 80) {
      scoreColor = const Color(0xFF10B981);
      scoreLabel = 'ممتاز';
    } else if (score >= 60) {
      scoreColor = const Color(0xFFFBBF24);
      scoreLabel = 'جيد';
    } else {
      scoreColor = const Color(0xFFEF4444);
      scoreLabel = 'ضعيف';
    }

    return Row(
      children: [
        Icon(
          Icons.assignment_turned_in_rounded,
          color: Colors.white.withValues(alpha: 0.8),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              // Score badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  scoreLabel,
                  style: GoogleFonts.cairo(
                    color: scoreColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Score text
              Text(
                '${score.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              // Details
              Expanded(
                child: Text(
                  '$correctCount من $totalQuestions',
                  style: GoogleFonts.cairo(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoExamsYet(bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.assignment_outlined,
          color: Colors.white.withValues(alpha: 0.5),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          'لم تخضع لأي اختبار بعد',
          style: GoogleFonts.cairo(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLoading(bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.hourglass_empty_rounded,
          color: Colors.white.withValues(alpha: 0.5),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          'جارٍ تحميل الإحصائيات...',
          style: GoogleFonts.cairo(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cairo(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
