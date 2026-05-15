import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/presentation/screens/exam_management_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/topic_management_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/theoretical_section_management_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/presentation/screens/practical_management_screen.dart';

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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        // Collect existing section names to enforce one-of-each rule
        final existingNames = docs
            .map(
              (d) =>
                  (d.data() as Map<String, dynamic>)['name'] as String? ?? '',
            )
            .toSet();
        final hasTheory = existingNames.any((n) => n.contains('نظري'));
        final hasPractical = existingNames.any((n) => n.contains('عملي'));
        final canAddMore = !hasTheory || !hasPractical;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 56,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد أقسام مضافة لهذه المادة',
                  style: GoogleFonts.cairo(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showAddSectionDialog(
                    context,
                    hasTheory: hasTheory,
                    hasPractical: hasPractical,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text('إضافة قسم', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          );
        }

        final List<Widget> cards = [];

        cards.addAll(
          docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? '';
            final isTheory = name.contains('نظري');

            return Stack(
              children: [
                Positioned.fill(
                  child: _buildDashboardCard(
                    context,
                    title: name,
                    subtitle: isTheory
                        ? 'القسم النظري للمادة'
                        : 'القسم العملي للمادة',
                    icon: isTheory
                        ? Icons.menu_book_rounded
                        : Icons.science_rounded,
                    color: isTheory ? Colors.blue : Colors.teal,
                    isDark: isDark,
                    onTap: () {
                      if (isTheory) {
                        Navigator.push(
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
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PracticalManagementScreen(
                              subjectId: subjectId,
                              subjectName: subjectName,
                              sectionId: doc.id,
                              sectionName: name,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                // Visible delete button in top-end corner (left in RTL)
                Positioned.directional(
                  textDirection: TextDirection.rtl,
                  top: -5,
                  start: -5,
                  child: GestureDetector(
                    onTap: () => _confirmDeleteSection(context, doc.id, name),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 14,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        );

        // Only show "Add" card if we can still add a section
        if (canAddMore) {
          cards.add(
            _buildAddSectionCard(
              context,
              isDark,
              hasTheory: hasTheory,
              hasPractical: hasPractical,
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 1.2,
          ),
          shrinkWrap: true,
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  Widget _buildDashboardGrid(BuildContext context, bool isDark) {
    final isPractical = sectionName?.contains('عملي') == true;
    final isTheory = sectionName?.contains('نظري') == true;

    // ── Theory-only cards ──────────────────────────────────────
    final theoryCards = <Widget>[
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
              breadcrumbs: [...breadcrumbs, sectionName!],
            ),
          ),
        ),
      ),
      _buildDashboardCard(
        context,
        title: 'إدارة الفصول والدروس',
        subtitle: 'إدارة ومعاينة الفصول والدروس والفقرات',
        icon: Icons.account_tree_rounded,
        color: Colors.orange,
        isDark: isDark,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TopicManagementScreen(
              subjectId: subjectId,
              subjectName: subjectName,
              breadcrumbs: [...breadcrumbs, sectionName!],
              sectionId: sectionId!,
              sectionName: sectionName!,
            ),
          ),
        ),
      ),
    ];

    // ── Practical-only card ─────────────────────────────────────
    final practicalCard = _buildDashboardCard(
      context,
      title: 'إدارة المحتوى العملي',
      subtitle: 'المذاكرات والرسومات والتجارب',
      icon: Icons.science_rounded,
      color: Colors.teal,
      isDark: isDark,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PracticalManagementScreen(
            subjectId: subjectId,
            subjectName: subjectName,
            sectionId: sectionId!,
            sectionName: sectionName!,
          ),
        ),
      ),
    );

    // ── Exams card — shown in both sections ─────────────────────
    final examsCard = _buildDashboardCard(
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
            sectionId: sectionId!,
            subjectName: subjectName,
            breadcrumbs: [...breadcrumbs, sectionName!],
          ),
        ),
      ),
    );

    // ── Build final list based on section type ──────────────────
    final items = <Widget>[
      if (isTheory) ...theoryCards,
      if (isPractical) practicalCard,
      examsCard,
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
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
                if (entry.key > 0)
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.value,
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.borderLight,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
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

  Widget _buildAddSectionCard(
    BuildContext context,
    bool isDark, {
    required bool hasTheory,
    required bool hasPractical,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.borderLight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddSectionDialog(
            context,
            hasTheory: hasTheory,
            hasPractical: hasPractical,
          ),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.grey[400],
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'إضافة قسم',
                style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSectionDialog(
    BuildContext context, {
    required bool hasTheory,
    required bool hasPractical,
  }) {
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
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يُسمح بقسم نظري واحد وقسم عملي واحد فقط لكل مادة',
              style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
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
                    isDisabled: hasTheory,
                    onTap: hasTheory
                        ? null
                        : () => _addSectionAndPop(context, 'القسم النظري'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSectionTypeOption(
                    context,
                    title: 'القسم العملي',
                    icon: Icons.science_rounded,
                    color: Colors.teal,
                    isDisabled: hasPractical,
                    onTap: hasPractical
                        ? null
                        : () => _addSectionAndPop(context, 'القسم العملي'),
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

  Widget _buildSectionTypeOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    final effectiveColor = isDisabled ? Colors.grey : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
          color: effectiveColor.withValues(alpha: 0.05),
        ),
        child: Column(
          children: [
            Icon(icon, color: effectiveColor, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (isDisabled) ...[
              const SizedBox(height: 4),
              Text(
                'تمت الإضافة مسبقاً',
                style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSection(
    BuildContext context,
    String sectionId,
    String sectionName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حذف القسم',
          style: GoogleFonts.cairo(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف "$sectionName"؟\nسيؤدي هذا إلى حذف جميع البيانات المرتبطة به.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseService().deleteDoc(
                DatabaseService.colSections,
                sectionId,
              );
            },
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _addSectionAndPop(BuildContext context, String name) async {
    await DatabaseService().addSection(subjectId, {'name': name});
    if (context.mounted) Navigator.pop(context);
  }
}
