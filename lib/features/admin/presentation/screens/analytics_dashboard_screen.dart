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
    return FutureBuilder<Map<String, String>>(
      future: _fetchGlobalAnalytics(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {
          'exams': '...',
          'success': '...',
          'engagement': '...',
        };

        return Row(
          children: [
            Expanded(child: _buildCard('الاختبارات المنجزة', stats['exams']!, Icons.assignment_turned_in, Colors.green, isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildCard('نسبة النجاح العامة', stats['success']!, Icons.trending_up, Colors.blue, isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildCard('تفاعل الطلاب', stats['engagement']!, Icons.local_fire_department_rounded, Colors.orange, isDark)),
          ],
        );
      }
    );
  }

  Future<Map<String, String>> _fetchGlobalAnalytics() async {
    try {
      // 1. Total Exams
      final examsCount = await _db.collection('exam_attempts').count().get();
      
      // 2. Success Rate (Average of all questions' success rates)
      final questions = await _db.collection('questions')
          .where('analytics.timesAnswered', isGreaterThan: 0)
          .get();
      
      double totalSuccess = 0;
      int count = 0;
      for (var doc in questions.docs) {
        final data = doc.data();
        final analytics = data['analytics'] as Map<String, dynamic>?;
        if (analytics != null) {
          totalSuccess += (analytics['successRate'] as num?)?.toDouble() ?? 0;
          count++;
        }
      }
      final avgSuccess = count > 0 ? (totalSuccess / count) * 100 : 0.0;

      // 3. Engagement (Unique users who have quiz attempts)
      // Note: For true uniqueness we'd need a complex query or aggregation, 
      // but for dashboard we can estimate or count active users.
      final usersCount = await _db.collection('users').count().get();

      return {
        'exams': _formatNumber(examsCount.count ?? 0),
        'success': '${avgSuccess.toStringAsFixed(1)}%',
        'engagement': _formatNumber(usersCount.count ?? 0),
      };
    } catch (e) {
      return {
        'exams': '0',
        'success': '0%',
        'engagement': '0',
      };
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
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
