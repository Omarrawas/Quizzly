import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/presentation/screens/exam_management_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/topic_management_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/theoretical_section_management_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';

class SubjectDashboardScreen extends StatelessWidget {
  final String subjectId;
  final String subjectName;
  final List<String> breadcrumbs;

  const SubjectDashboardScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.breadcrumbs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(subjectName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(isDark),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 1,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildDashboardCard(
                  context,
                  title: 'بنك الأسئلة',
                  subtitle: 'إضافة وتعديل الأسئلة (نظري وعملي)',
                  icon: Icons.quiz_rounded,
                  color: Colors.blue,
                  isDark: isDark,
                  onTap: () => _showSectionChoice(context),
                ),
                _buildDashboardCard(
                  context,
                  title: 'إدارة الاختبارات',
                  subtitle: 'الدورات السابقة والاختبارات التجريبية',
                  icon: Icons.assignment_rounded,
                  color: Colors.purple,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExamManagementScreen(
                        subjectId: subjectId,
                        subjectName: subjectName,
                        breadcrumbs: [...breadcrumbs, subjectName],
                      ),
                    ),
                  ),
                ),
                _buildDashboardCard(
                  context,
                  title: 'تصنيف المادة',
                  subtitle: 'إدارة الفصول والدروس والفقرات',
                  icon: Icons.account_tree_rounded,
                  color: Colors.orange,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TopicManagementScreen(
                        subjectId: subjectId,
                        subjectName: subjectName,
                        breadcrumbs: [...breadcrumbs, subjectName],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: breadcrumbs.asMap().entries.map((entry) {
            return Row(
              children: [
                if (entry.key > 0) Icon(Icons.chevron_left_rounded, size: 16, color: Colors.grey[400]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.value,
                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required bool isDark, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
        boxShadow: [
          if (!isDark) BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(subtitle, style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[400], size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSectionChoice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(DatabaseService.colSections)
            .where('parentId', isEqualTo: subjectId)
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Text('لا توجد أقسام مضافة لهذه المادة', style: GoogleFonts.cairo()));

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('اختر القسم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 20),
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: Icon(data['name'].contains('نظري') ? Icons.menu_book_rounded : Icons.science_rounded, color: AppColors.primaryBlue),
                    title: Text(data['name'], style: GoogleFonts.cairo()),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TheoreticalSectionManagementScreen(
                            sectionId: doc.id,
                            sectionName: data['name'],
                            subjectId: subjectId,
                            breadcrumbs: [...breadcrumbs, subjectName],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
