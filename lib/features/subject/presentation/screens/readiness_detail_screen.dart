import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/domain/services/readiness_service.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';

class ReadinessDetailScreen extends StatelessWidget {
  final String subjectId;
  final String subjectName;

  const ReadinessDetailScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthService>().user?.uid ?? '';
    final readinessService = ReadinessService();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'تفاصيل الجاهزية', 
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          )
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<double>(
        stream: readinessService.streamReadinessScore(userId, subjectId),
        builder: (context, snapshot) {
          final readiness = snapshot.data ?? 0.0;
          final percentage = (readiness * 100).toInt();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildMainGauge(percentage, isDark),
                const SizedBox(height: 24),
                _buildInsightCard(percentage, isDark),
                const SizedBox(height: 24),
                _buildTopicBreakdown(userId, isDark),
                const SizedBox(height: 24),
                _buildActionList(percentage, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainGauge(int percentage, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), 
            blurRadius: 20
          )
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 15,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percentage > 80 ? Colors.green : (percentage > 50 ? AppColors.primaryBlue : Colors.orange),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percentage%',
                    style: GoogleFonts.inter(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'جاهزية',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            percentage > 80 
                ? 'أنت مستعد تماماً للتفوق!' 
                : (percentage > 50 ? 'أداء جيد، استمر في المراجعة.' : 'تحتاج لمزيد من التدريب المكثف.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(int percentage, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.3 : 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              Text(
                'نصيحة ذكية',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue[300] : AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getAdvice(percentage),
            style: GoogleFonts.cairo(
              color: isDark ? Colors.white70 : AppColors.textPrimary, 
              height: 1.6
            ),
          ),
        ],
      ),
    );
  }

  String _getAdvice(int p) {
    if (p > 80) return 'لقد غطيت معظم المادة بشكل ممتاز. ركز الآن على الأسئلة الصعبة في قسم "الإجابات الخاطئة" للحفاظ على مستواك.';
    if (p > 50) return 'لقد بدأت تتقن المادة، لكن هناك فجوات في التغطية. جرب استخدام "البحث" لاستكشاف الأسئلة التي لم تمر عليها بعد.';
    return 'مستوى الجاهزية منخفض حالياً. ابدأ بالدراسة حسب "التصنيفات" لتغطية المادة بشكل منهجي، ثم استخدم "المراجعة الذكية" لتثبيت الحفظ.';
  }

  Widget _buildActionList(int percentage, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'خطوات مقترحة للتحسين',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold, 
            fontSize: 16,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildStepItem(Icons.repeat_rounded, 'استخدم المراجعة الذكية يومياً', Colors.purple, isDark),
        _buildStepItem(Icons.error_outline_rounded, 'صحح أخطاءك السابقة فوراً', Colors.red, isDark),
        _buildStepItem(Icons.grid_view_rounded, 'غطِّ كافة التصنيفات المتاحة', Colors.orange, isDark),
      ],
    );
  }

  Widget _buildStepItem(IconData icon, String label, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            label, 
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            )
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildTopicBreakdown(String userId, bool isDark) {
    final readinessService = ReadinessService();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تحليل التصنيفات',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold, 
            fontSize: 16,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, double>>(
          future: readinessService.getTopicReadiness(userId, subjectId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final scores = snapshot.data!;
            if (scores.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.map_rounded, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'خارطة إتقان المادة',
                      style: GoogleFonts.cairo(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.white : const Color(0xFF0F172A)
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا توجد بيانات كافية بعد.\nابدأ بحل بعض الأسئلة لنرى تحليل إتقانك هنا!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 13, 
                        color: isDark ? Colors.white38 : Colors.grey[600]
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: scores.entries.map((e) => _buildTopicItem(e.key, e.value, isDark)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopicItem(String topicId, double score, bool isDark) {
    final percentage = (score * 100).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تصنيف: $topicId', // In a real app, fetch name from ID
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w600, 
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              Text(
                '$percentage%',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _getScoreColor(score)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
              valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score > 0.8) return Colors.green;
    if (score > 0.5) return AppColors.primaryBlue;
    return Colors.orange;
  }
}
