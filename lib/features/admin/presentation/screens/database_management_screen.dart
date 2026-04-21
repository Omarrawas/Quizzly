import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/home/data/models/college_model.dart';

class DatabaseManagementScreen extends StatefulWidget {
  const DatabaseManagementScreen({super.key});

  @override
  State<DatabaseManagementScreen> createState() => _DatabaseManagementScreenState();
}

class _DatabaseManagementScreenState extends State<DatabaseManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildManagementList(context, 'الجامعات', isDark),
          _buildManagementList(context, 'الكليات', isDark),
          _buildManagementList(context, 'الفصول', isDark),
          _buildManagementList(context, 'المواد', isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntryDialog(context, _tabController.index),
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildManagementList(BuildContext context, String title, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3, // Mock data count
      itemBuilder: (context, index) {
        return _buildEntryCard(
          context,
          'عنوان $title ${index + 1}',
          'وصف تفصيلي أو معلومة إضافية عن $title',
          isDark,
        );
      },
    );
  }

  Widget _buildEntryCard(BuildContext context, String title, String subtitle, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          title,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {},
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text('تعديل', style: GoogleFonts.cairo())),
            PopupMenuItem(value: 'delete', child: Text('حذف', style: GoogleFonts.cairo(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context, int tabIndex) {
    final titles = ['جامعة', 'كلية', 'فصل', 'مادة'];
    final title = titles[tabIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة $title جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'اسم ال$title',
                labelStyle: GoogleFonts.cairo(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'الوصف أو المعلومات',
                labelStyle: GoogleFonts.cairo(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إضافة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }
}
