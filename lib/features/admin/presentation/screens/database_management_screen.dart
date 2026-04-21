import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';

class DatabaseManagementScreen extends StatefulWidget {
  const DatabaseManagementScreen({super.key});

  @override
  State<DatabaseManagementScreen> createState() => _DatabaseManagementScreenState();
}

class _DatabaseManagementScreenState extends State<DatabaseManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();

  // Selected hierarchy
  String? _selectedUniversityId;
  String? _selectedUniversityName;
  String? _selectedCollegeId;
  String? _selectedCollegeName;
  String? _selectedSemesterId;
  String? _selectedSemesterName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          'إدارة قاعدة البيانات',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'الجامعات'),
            Tab(text: 'الكليات'),
            Tab(text: 'الفصول'),
            Tab(text: 'المواد'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUniversityList(isDark),
                _buildCollegeList(isDark),
                _buildSemesterList(isDark),
                _buildSubjectList(isDark),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntryDialog(context, _tabController.index),
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBreadcrumbs(bool isDark) {
    if (_selectedUniversityId == null && _selectedCollegeId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 16, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedUniversityName != null) ...[
                    _breadcrumbItem(_selectedUniversityName!),
                    if (_selectedCollegeName != null) ...[
                      const Icon(Icons.chevron_right_rounded, size: 16),
                      _breadcrumbItem(_selectedCollegeName!),
                    ]
                  ],
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedUniversityId = null;
                _selectedUniversityName = null;
                _selectedCollegeId = null;
                _selectedCollegeName = null;
              });
            },
            child: Text('مسح الفلتر', style: GoogleFonts.cairo(fontSize: 10, color: Colors.red)),
          )
        ],
      ),
    );
  }

  Widget _breadcrumbItem(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
      ),
    );
  }

  // --- Universities Tab ---
  Widget _buildUniversityList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getUniversities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _emptyState('لا يوجد جامعات بعد', isDark);

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            return _buildEntryCard(
              context: context,
              title: data['name'] ?? 'بدون اسم',
              subtitle: data['description'] ?? 'لا يوجد وصف',
              isDark: isDark,
              onTap: () {
                setState(() {
                  _selectedUniversityId = id;
                  _selectedUniversityName = data['name'];
                  _tabController.animateTo(1); // Go to Colleges
                });
              },
              onDelete: () => _dbService.deleteUniversity(id),
              onEdit: () => _showEditDialog(context, id, data, 'university'),
            );
          },
        );
      },
    );
  }

  // --- Colleges Tab ---
  Widget _buildCollegeList(bool isDark) {
    if (_selectedUniversityId == null) {
      return _selectionRequiredState('يرجى اختيار جامعة أولاً من تبويب الجامعات', isDark, 0);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getColleges(_selectedUniversityId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _emptyState('لا يوجد كليات لهذه الجامعة', isDark);

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            return _buildEntryCard(
              context: context,
              title: data['name'] ?? '',
              subtitle: data['subtitle'] ?? '',
              isDark: isDark,
              onTap: () {
                setState(() {
                  _selectedCollegeId = id;
                  _selectedCollegeName = data['name'];
                  _tabController.animateTo(2); // Go to Semesters
                });
              },
              onDelete: () => _dbService.deleteUniversity(id), // Fix service call for subcollections
              onEdit: () {},
            );
          },
        );
      },
    );
  }

  // --- Semesters Tab ---
  Widget _buildSemesterList(bool isDark) {
    if (_selectedCollegeId == null) {
      return _selectionRequiredState('يرجى اختيار كلية أولاً من تبويب الكليات', isDark, 1);
    }
    return _emptyState('تبويب الفصول قيد التطوير', isDark); // Placeholder
  }

  // --- Subjects Tab ---
  Widget _buildSubjectList(bool isDark) {
    return _emptyState('تبويب المواد قيد التطوير', isDark); // Placeholder
  }

  // --- Helpers ---
  Widget _emptyState(String message, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.cairo(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _selectionRequiredState(String message, bool isDark, int targetTab) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 48, color: AppColors.primaryBlue.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.cairo(color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(targetTab),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
              child: Text('الذهاب للاختيار', style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    required VoidCallback onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.blue), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), onPressed: onDelete),
          ],
        ),
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context, int tabIndex) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة بيانات جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'الاسم', labelStyle: GoogleFonts.cairo())),
            const SizedBox(height: 16),
            TextField(controller: descController, decoration: InputDecoration(labelText: 'الوصف', labelStyle: GoogleFonts.cairo())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              if (name.isNotEmpty) {
                if (tabIndex == 0) {
                  await _dbService.addUniversity({'name': name, 'description': desc, 'createdAt': FieldValue.serverTimestamp()});
                } else if (tabIndex == 1 && _selectedUniversityId != null) {
                  await _dbService.addCollege(_selectedUniversityId!, {'name': name, 'subtitle': desc, 'status': 'demo', 'subjectCount': 0});
                }
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String id, Map<String, dynamic> data, String type) {
    final nameController = TextEditingController(text: data['name']);
    final descController = TextEditingController(text: data['description'] ?? data['subtitle']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل البيانات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 16),
            TextField(controller: descController, decoration: InputDecoration(labelText: 'الوصف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (type == 'university') {
                await _dbService.updateUniversity(id, {'name': nameController.text, 'description': descController.text});
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
