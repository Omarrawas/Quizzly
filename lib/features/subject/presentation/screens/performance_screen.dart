import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/domain/services/smart_quiz_service.dart';

class PerformanceScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const PerformanceScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final SmartQuizService _service = SmartQuizService();
  bool _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthService>().user?.uid;
    if (userId == null) return;

    final data = await _service.getPerformanceSummary(userId, widget.subjectId);
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'تحليل الأداء',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCard(isDark),
                    const SizedBox(height: 32),
                    _buildSectionTitle('نقاط الضعف (بحاجة لتركيز)', Icons.trending_down_rounded, Colors.red),
                    const SizedBox(height: 12),
                    _buildTopicsList(_data['weakTopics'] ?? [], isDark, Colors.red),
                    const SizedBox(height: 32),
                    _buildSectionTitle('نقاط القوة (ممتاز)', Icons.trending_up_rounded, Colors.green),
                    const SizedBox(height: 12),
                    _buildTopicsList(_data['strongTopics'] ?? [], isDark, Colors.green),
                    const SizedBox(height: 32),
                    _buildRecommendations(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewCard(bool isDark) {
    final double mastery = _data['totalMastery'] ?? 0.0;
    final int pct = (mastery * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: mastery,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Column(
                children: [
                  Text(
                    '$pct%',
                    style: GoogleFonts.cairo(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'الإتقان الكلي',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleStat('المواضيع', '${(_data['allStats'] as List?)?.length ?? 0}'),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildSimpleStat('الحالة', pct > 80 ? 'ممتاز' : pct > 50 ? 'جيد' : 'مبتدئ'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: GoogleFonts.cairo(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTopicsList(List<dynamic> topics, bool isDark, Color color) {
    if (topics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'لا توجد بيانات كافية بعد',
            style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: topics.map((t) {
        final double m = t['mastery'];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${(m * 100).round()}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['name'],
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: m,
                        backgroundColor: color.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecommendations(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'نصيحة كويزلي الذكية',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _data['weakTopics']?.isNotEmpty == true
                ? 'لقد لاحظنا أنك بحاجة لمزيد من التدريب في موضوع "${_data['weakTopics'][0]['name']}". نقترح عليك بدء "كويز ذكي" الآن للتركيز عليه.'
                : 'أداءك رائع! استمر في التدريب للحفاظ على مستواك العالي.',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: Colors.orange[800],
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to Smart Quiz
                Navigator.pop(context);
                // The parent screen should handle the navigation to Smart Quiz
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('ابدأ الكويز الذكي الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
