import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'لوحة التحليلات الذكية',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(isDark),
            const SizedBox(height: 24),
            Text('الأسئلة الأكثر إخفاقاً (Critical Questions)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _buildHardestQuestionsList(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    // In a real production app with Cloud Functions, these would fetch from 'analytics_summary/global'
    // For now, we mock some top-level aggregated data visually.
    return Row(
      children: [
        Expanded(child: _buildCard('الاختبارات المنجزة', '12.4K', Icons.assignment_turned_in, Colors.green, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildCard('نسبة النجاح العامة', '68%', Icons.trending_up, Colors.blue, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildCard('تفاعل الطلاب', '8.2K', Icons.local_fire_department_rounded, Colors.orange, isDark)),
      ],
    );
  }

  Widget _buildCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 24)),
          Text(title, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildHardestQuestionsList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      // Query questions that have been answered more than 5 times, sorted by lowest success rate
      stream: _db.collection(DatabaseService.colQuestions)
          .where('analytics.timesAnswered', isGreaterThan: 5)
          .orderBy('analytics.timesAnswered')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // If index is missing, we handle it gracefully
          return Center(child: Text('يجب بناء الفهرس (Index) في Firebase أولاً. ${snapshot.error}', style: GoogleFonts.cairo(fontSize: 12)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text('لا توجد بيانات كافية للتحليل بعد.\n(الأسئلة ستبدأ بالظهور هنا بعد 5 محاولات على الأقل)', 
                textAlign: TextAlign.center, 
                style: GoogleFonts.cairo(color: AppColors.textSecondary)
              ),
            ),
          );
        }

        // We fetch and sort manually by success rate to find the hardest
        var docs = snapshot.data!.docs;
        var questions = docs.map((d) => QuizQuestion.fromFirestore(d)).toList();
        
        // Sort by lowest success rate
        questions.sort((a, b) => a.analytics.successRate.compareTo(b.analytics.successRate));
        
        // Take top 10 hardest
        final hardest = questions.take(10).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: hardest.length,
          itemBuilder: (context, index) {
            final q = hardest[index];
            final successRatePct = (q.analytics.successRate * 100).toStringAsFixed(1);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: q.analytics.successRate < 0.4 ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('$successRatePct%', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12, color: q.analytics.successRate < 0.4 ? Colors.red : Colors.orange)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people_alt_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('${q.analytics.timesAnswered} محاولة', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 16),
                            Icon(Icons.timer_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('متوسط الوقت: ${q.analytics.avgTime.toStringAsFixed(1)} ث', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue),
                    tooltip: 'تعديل السؤال',
                    onPressed: () {
                      // Navigate to question editor or show dialog
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب الدخول عبر إدارة المادة لتعديل السؤال حالياً.')));
                    },
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
