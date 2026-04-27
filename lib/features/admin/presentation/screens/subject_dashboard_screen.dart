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
  final String? sectionId;
  final String? sectionName;

  const SubjectDashboardScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.breadcrumbs,
    this.sectionId,
    this.sectionName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          sectionName != null ? '$subjectName - $sectionName' : subjectName,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(isDark),
          Expanded(
            child: sectionId == null
                ? _buildSectionSelector(context, isDark)
                : _buildDashboardGrid(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector(BuildContext context, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(DatabaseService.colSections)
          .where('parentId', isEqualTo: subjectId)
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Text('لا توجد أقسام مضافة لهذه المادة', style: GoogleFonts.cairo()),
          );
        }

        final List<Widget> cards = [];
        
        // Removed "Global Bank" card as per user request


        cards.addAll(docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] ?? '';
          final isTheory = name.contains('نظري');

          return _buildDashboardCard(
            context,
            title: name,
            subtitle: isTheory ? 'القسم النظري للمادة' : 'القسم العملي للمادة',
            icon: isTheory ? Icons.menu_book_rounded : Icons.science_rounded,
            color: isTheory ? Colors.blue : Colors.teal,
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubjectDashboardScreen(
                  subjectId: subjectId,
                  subjectName: subjectName,
                  breadcrumbs: [...breadcrumbs, subjectName],
                  sectionId: doc.id,
                  sectionName: name,
                ),
              ),
            ),
          );
        }));

        // Add "Add Section" card
        cards.add(
          _buildAddSectionCard(context, isDark),
        );

        return GridView.count(
          padding: const EdgeInsets.all(24),
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 1.2,
          children: cards,
        );
      },
    );
  }

  Widget _buildDashboardGrid(BuildContext context, bool isDark) {
    return GridView.count(
      padding: const EdgeInsets.all(24),
      crossAxisCount: 3,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: 0.85,
      children: [
        _buildDashboardCard(
          context,
          title: 'بنك الأسئلة',
          subtitle: 'إدارة الأسئلة',
          icon: Icons.quiz_rounded,
          color: Colors.blue,
          isDark: isDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TheoreticalSectionManagementScreen(
                sectionId: sectionId!,
                sectionName: sectionName!,
                subjectId: subjectId,
                breadcrumbs: [...breadcrumbs, subjectName, sectionName!],
              ),
            ),
          ),
        ),
        _buildDashboardCard(
          context,
          title: 'إدارة الاختبارات',
          subtitle: 'الدورات والاختبارات',
          icon: Icons.assignment_rounded,
          color: Colors.purple,
          isDark: isDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExamManagementScreen(
                subjectId: subjectId,
                subjectName: subjectName,
                breadcrumbs: [...breadcrumbs, subjectName, sectionName!],
              ),
            ),
          ),
        ),
        _buildDashboardCard(
          context,
          title: 'تصنيف المادة',
          subtitle: 'الفصول والدروس والفقرات',
          icon: Icons.account_tree_rounded,
          color: Colors.orange,
          isDark: isDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopicManagementScreen(
                subjectId: subjectId,
                subjectName: subjectName,
                breadcrumbs: [...breadcrumbs, subjectName, sectionName!],
                sectionId: sectionId!,
                sectionName: sectionName!,
              ),
            ),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
        boxShadow: [
          if (!isDark) BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddSectionCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight, style: BorderStyle.solid),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddSectionDialog(context),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded, color: Colors.grey[400], size: 32),
              const SizedBox(height: 12),
              Text('إضافة قسم جديد', style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'إضافة قسم للمادة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildSectionTypeOption(
                    context,
                    title: 'القسم النظري',
                    icon: Icons.menu_book_rounded,
                    color: Colors.blue,
                    onTap: () => _addSectionAndPop(context, 'القسم النظري'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSectionTypeOption(
                    context,
                    title: 'القسم العملي',
                    icon: Icons.science_rounded,
                    color: Colors.teal,
                    onTap: () => _addSectionAndPop(context, 'القسم العملي'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTypeOption(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.05),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSectionAndPop(BuildContext context, String name) async {
    await DatabaseService().addSection(subjectId, {
      'name': name,
    });
    if (context.mounted) Navigator.pop(context);
  }
}
