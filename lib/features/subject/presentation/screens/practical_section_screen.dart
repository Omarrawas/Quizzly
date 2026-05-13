import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/practical_models.dart';
import 'package:quizzly/features/subject/presentation/screens/practical_category_list_screen.dart';

class PracticalSectionScreen extends StatelessWidget {
  final String subjectId;
  final String subjectName;

  const PracticalSectionScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  /// Fetches the sectionId of the practical section for this subject.
  /// Looks in the 'sections' collection for a section whose name contains 'عملي'
  /// and belongs to this subject.
  Future<String?> _fetchPracticalSectionId() async {
    final snap = await FirebaseFirestore.instance
        .collection('sections')
        .where('parentId', isEqualTo: subjectId)
        .get();
    for (final doc in snap.docs) {
      final name = (doc.data()['name'] ?? '') as String;
      if (name.contains('عملي')) {
        return doc.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0D9488); // Emerald Teal

    return FutureBuilder<String?>(
      future: _fetchPracticalSectionId(),
      builder: (context, sectionSnap) {
        final sectionId = sectionSnap.data; // may be null if not found yet

        return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الدفتر العملي',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, 
            color: isDark ? Colors.white : AppColors.textPrimary, 
            size: 20
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark, primaryColor),
            const SizedBox(height: 24),
            Text(
              'اختر نوع المحتوى',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                _buildCategoryCard(
                  context,
                  title: 'المذاكرات الدورية',
                  subtitle: 'ملخصات مكتوبة وشاملة',
                  icon: Icons.description_rounded,
                  color: const Color(0xFF0D9488),
                  category: PracticalCategory.summary,
                  isDark: isDark,
                  sectionId: sectionId,
                ),
                _buildCategoryCard(
                  context,
                  title: 'الأطلس المجهري',
                  subtitle: 'رسومات وتوضيحات مجهرية',
                  icon: Icons.biotech_rounded,
                  color: const Color(0xFF0891B2),
                  category: PracticalCategory.drawing,
                  isDark: isDark,
                  sectionId: sectionId,
                ),
                _buildCategoryCard(
                  context,
                  title: 'دليل التجارب',
                  subtitle: 'شرح خطوات العمل المخبري',
                  icon: Icons.science_rounded,
                  color: const Color(0xFF4F46E5),
                  category: PracticalCategory.experiment,
                  isDark: isDark,
                  sectionId: sectionId,
                ),
                _buildCategoryCard(
                  context,
                  title: 'بنك المقابلات',
                  subtitle: 'أسئلة المقابلة الشفهية',
                  icon: Icons.record_voice_over_rounded,
                  color: const Color(0xFF7C3AED),
                  category: PracticalCategory.interview,
                  isDark: isDark,
                  sectionId: sectionId,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildRecentActivity(isDark),
          ],
        ),
      ),
        ); // end Scaffold
      }, // end FutureBuilder builder
    ); // end FutureBuilder
  }

  Widget _buildHeader(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً بك في القسم العملي',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'هنا تجد كل ما يخص الجانب التطبيقي والمذاكرات الدورية للمقرر.',
                  style: GoogleFonts.cairo(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required PracticalCategory category,
    required bool isDark,
    required String? sectionId,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PracticalCategoryListScreen(
                  subjectId: subjectId,
                  sectionId: sectionId,
                  category: category,
                  title: title,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const Spacer(),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أحدث الإضافات',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.new_releases_rounded, color: Color(0xFF0D9488), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تمت إضافة مذاكرة الأسبوع الرابع',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'منذ ساعتين',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'عرض',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFF0D9488),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
