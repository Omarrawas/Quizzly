import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/admin/presentation/screens/theoretical_section_management_screen.dart';

import 'package:quizzly/features/admin/presentation/screens/exam_management_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/topic_management_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/analytics_dashboard_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/subject_dashboard_screen.dart';

enum ManagementLevel { university, college, department, year, semester, subject, section }

class DatabaseManagementScreen extends StatefulWidget {
  const DatabaseManagementScreen({super.key});

  @override
  State<DatabaseManagementScreen> createState() => _DatabaseManagementScreenState();
}

class _DatabaseManagementScreenState extends State<DatabaseManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  ManagementLevel _currentLevel = ManagementLevel.university;

  // Track parent IDs and names for the current view
  final Map<ManagementLevel, String> _parentIds = {};
  final Map<ManagementLevel, String> _levelNames = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: _currentLevel != ManagementLevel.university
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: _goBack,
              )
            : null,
        title: Text(
          _getPageTitle(),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'لوحة التحليلات الذكية',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(isDark),
          Expanded(child: _buildCurrentLevelList(isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  String _getPageTitle() {
    switch (_currentLevel) {
      case ManagementLevel.university: return 'الجامعات';
      case ManagementLevel.college: return 'الكليات';
      case ManagementLevel.department: return 'الأقسام';
      case ManagementLevel.year: return 'السنوات الدراسية';
      case ManagementLevel.semester: return 'الفصول الدراسية';
      case ManagementLevel.subject: return 'المواد';
      case ManagementLevel.section: return 'أقسام المادة';
    }
  }

  void _goBack() {
    setState(() {
      switch (_currentLevel) {
        case ManagementLevel.college: _currentLevel = ManagementLevel.university; break;
        case ManagementLevel.department: _currentLevel = ManagementLevel.college; break;
        case ManagementLevel.year: _currentLevel = ManagementLevel.department; break;
        case ManagementLevel.semester: _currentLevel = ManagementLevel.year; break;
        case ManagementLevel.subject: _currentLevel = ManagementLevel.semester; break;
        case ManagementLevel.section: _currentLevel = ManagementLevel.subject; break;
        default: break;
      }
    });
  }

  Widget _buildBreadcrumbs(bool isDark) {
    List<String> path = [];
    for (var level in ManagementLevel.values) {
      if (level.index < _currentLevel.index && _levelNames.containsKey(level)) {
        path.add(_levelNames[level]!);
      }
    }

    if (path.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: path.asMap().entries.map((entry) {
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

  Widget _buildCurrentLevelList(bool isDark) {
    Stream<QuerySnapshot> stream;
    switch (_currentLevel) {
      case ManagementLevel.university: stream = _dbService.getUniversities(); break;
      case ManagementLevel.college: stream = _dbService.getColleges(_parentIds[ManagementLevel.university]!); break;
      case ManagementLevel.department: stream = _dbService.getDepartments(_parentIds[ManagementLevel.college]!); break;
      case ManagementLevel.year: stream = _dbService.getYears(_parentIds[ManagementLevel.department]!); break;
      case ManagementLevel.semester: stream = _dbService.getSemesters(_parentIds[ManagementLevel.year]!); break;
      case ManagementLevel.subject: stream = _dbService.getSubjects(_parentIds[ManagementLevel.semester]!); break;
      case ManagementLevel.section: stream = _dbService.getSections(_parentIds[ManagementLevel.subject]!); break;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        if (snapshot.hasError) {
          return _emptyState('حدث خطأ أثناء جلب البيانات: ${snapshot.error}', isDark, isError: true);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _emptyState('لا توجد بيانات متاحة حالياً', isDark);

        final docs = snapshot.data!.docs;
        
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final name = data['name'] ?? '';
            return _buildManagementCard(
              key: ValueKey(id),
              title: name,
              subtitle: data['description'] ?? data['subtitle'] ?? '',
              isDark: isDark,
              onTap: () => _onItemTap(id, name, _currentLevel),
              onEdit: () => _showEditDialog(id, data),
              onDelete: () => _confirmDelete(id, name),
            );
          },
          onReorder: (oldIndex, newIndex) => _handleReorder(docs, oldIndex, newIndex),
        );
      },
    );
  }

  Future<void> _handleReorder(List<QueryDocumentSnapshot> docs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final List<String> ids = docs.map((d) => d.id).toList();
    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);
    try {
      await _dbService.updateOrder(_getCollectionName(_currentLevel), ids);
      _showStatusSnackBar('تم تحديث الترتيب بنجاح', isError: false);
    } catch (e) {
      _showStatusSnackBar('فشل تحديث الترتيب: $e', isError: true);
    }
  }

  void _onItemTap(String id, String name, ManagementLevel fromLevel) {
    if (fromLevel == ManagementLevel.subject) {
      List<String> breadcrumbs = [];
      for (var level in ManagementLevel.values) {
        if (level.index < ManagementLevel.subject.index && _levelNames.containsKey(level)) {
          breadcrumbs.add(_levelNames[level]!);
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubjectDashboardScreen(
            subjectId: id,
            subjectName: name,
            breadcrumbs: breadcrumbs,
          ),
        ),
      );
      return;
    }

    if (fromLevel == ManagementLevel.section) {
      List<String> breadcrumbs = [];
      for (var level in ManagementLevel.values) {
        if (level.index <= ManagementLevel.subject.index && _levelNames.containsKey(level)) {
          breadcrumbs.add(_levelNames[level]!);
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheoreticalSectionManagementScreen(
            sectionId: id,
            sectionName: name,
            subjectId: _parentIds[ManagementLevel.subject]!,
            breadcrumbs: breadcrumbs,
          ),
        ),
      );
      return;
    }

    setState(() {
      _parentIds[fromLevel] = id;
      _levelNames[fromLevel] = name;
      _currentLevel = ManagementLevel.values[fromLevel.index + 1];
    });
  }

  void _goToTopics(String subjectId, String sectionId, String name) {
    List<String> breadcrumbs = [];
    for (var level in ManagementLevel.values) {
      if (level.index <= ManagementLevel.subject.index && _levelNames.containsKey(level)) {
        breadcrumbs.add(_levelNames[level]!);
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TopicManagementScreen(
          subjectId: subjectId,
          sectionId: sectionId,
          subjectName: _levelNames[ManagementLevel.subject] ?? name,
          sectionName: name,
          breadcrumbs: breadcrumbs,
        ),
      ),
    );
  }

  void _goToExams(String subjectId, String sectionId, String name) {
    List<String> breadcrumbs = [];
    for (var level in ManagementLevel.values) {
      if (level.index <= ManagementLevel.subject.index && _levelNames.containsKey(level)) {
        breadcrumbs.add(_levelNames[level]!);
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamManagementScreen(
          subjectId: subjectId,
          sectionId: sectionId,
          subjectName: name,
          breadcrumbs: breadcrumbs,
        ),
      ),
    );
  }

  String _getCollectionName(ManagementLevel level) {
    switch (level) {
      case ManagementLevel.university: return DatabaseService.colUniversities;
      case ManagementLevel.college: return DatabaseService.colColleges;
      case ManagementLevel.department: return DatabaseService.colDepartments;
      case ManagementLevel.year: return DatabaseService.colYears;
      case ManagementLevel.semester: return DatabaseService.colSemesters;
      case ManagementLevel.subject: return DatabaseService.colSubjects;
      case ManagementLevel.section: return DatabaseService.colSections;
    }
  }

  Widget _buildManagementCard({required Key key, required String title, required String subtitle, required bool isDark, required VoidCallback onTap, required VoidCallback onEdit, required VoidCallback onDelete}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentLevel == ManagementLevel.section) ...[
              IconButton(
                icon: const Icon(Icons.assignment_outlined, color: Colors.purple, size: 22),
                onPressed: () => _goToExams(
                  _parentIds[ManagementLevel.subject]!,
                  (key as ValueKey<String>).value,
                  title,
                ),
                tooltip: 'إدارة الاختبارات',
              ),
              IconButton(
                icon: const Icon(Icons.account_tree_rounded, color: AppColors.primaryBlue, size: 22),
                onPressed: () => _goToTopics(
                  _parentIds[ManagementLevel.subject]!,
                  (key as ValueKey<String>).value,
                  title,
                ),
                tooltip: 'إدارة المواضيع',
              ),
            ],
            IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 22), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22), onPressed: onDelete),
            const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message, bool isDark, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.inventory_2_outlined,
              size: 48,
              color: isError ? Colors.red.withValues(alpha: 0.5) : (isDark ? Colors.white24 : Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            SelectableText(
              message,
              style: GoogleFonts.cairo(color: isError ? Colors.red : AppColors.textSecondary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            if (isError) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() {}),
                child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showStatusSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }

  void _showEditDialog(String id, Map<String, dynamic> currentData) {
    final nameController = TextEditingController(text: currentData['name']);
    final descController = TextEditingController(text: currentData['description'] ?? currentData['subtitle']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تعديل ${_getAddLabel()}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
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
              final updatedData = {
                'name': nameController.text.trim(),
                if (_currentLevel == ManagementLevel.college) 'subtitle': descController.text.trim()
                else 'description': descController.text.trim(),
              };
              try {
                await _dbService.updateDoc(_getCollectionName(_currentLevel), id, updatedData);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showStatusSnackBar('تم التعديل بنجاح', isError: false);
                }
              } catch (e) {
                if (context.mounted) _showStatusSnackBar('فشل التعديل: $e', isError: true);
              }
            },
            child: Text('حفظ التغييرات'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت متأكد من حذف ($name)؟\nسيتم حذف البيانات المرتبطة بها نهائياً.', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(
            onPressed: () async {
              try {
                await _dbService.deleteDoc(_getCollectionName(_currentLevel), id);
                if (context.mounted) {
                  Navigator.pop(context);
                  _showStatusSnackBar('تم الحذف بنجاح', isError: false);
                }
              } catch (e) {
                if (context.mounted) _showStatusSnackBar('فشل الحذف: $e', isError: true);
              }
            },
            child: Text('حذف نهائي', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSemesterSelectionDialog() {
    final semesters = ['الفصل الأول', 'الفصل الثاني', 'الفصل الثالث'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('إضافة فصل جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: semesters.map((sem) => ListTile(
            title: Text(sem, style: GoogleFonts.cairo()),
            onTap: () async {
              await _performAdd(sem, '');
              if (context.mounted) Navigator.pop(context);
            },
            trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
        ],
      ),
    );
  }

  void _showSectionSelectionDialog() {
    final sections = ['القسم النظري', 'القسم العملي'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('إضافة قسم للمادة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sections.map((sec) => ListTile(
            title: Text(sec, style: GoogleFonts.cairo()),
            onTap: () async {
              await _performAdd(sec, '');
              if (context.mounted) Navigator.pop(context);
            },
            trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    if (_currentLevel == ManagementLevel.semester) {
      _showSemesterSelectionDialog();
      return;
    }
    if (_currentLevel == ManagementLevel.section) {
      _showSectionSelectionDialog();
      return;
    }
    
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('إضافة ${_getAddLabel()} جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'الاسم', labelStyle: GoogleFonts.cairo())),
            const SizedBox(height: 16),
            TextField(controller: descController, decoration: InputDecoration(labelText: 'الوصف (اختياري)', labelStyle: GoogleFonts.cairo())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              if (name.isNotEmpty) {
                await _performAdd(name, desc);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  String _getAddLabel() {
    switch (_currentLevel) {
      case ManagementLevel.university: return 'جامعة';
      case ManagementLevel.college: return 'كلية';
      case ManagementLevel.department: return 'قسم';
      case ManagementLevel.year: return 'سنة دراسية';
      case ManagementLevel.semester: return 'فصل دراسي';
      case ManagementLevel.subject: return 'مادة';
      case ManagementLevel.section: return 'قسم المادة';
    }
  }

  Future<void> _performAdd(String name, String desc) async {
    final Map<String, dynamic> data = {
      'name': name,
      _currentLevel == ManagementLevel.college ? 'subtitle' : 'description': desc,
    };

    try {
      switch (_currentLevel) {
        case ManagementLevel.university: await _dbService.addUniversity(data); break;
        case ManagementLevel.college: await _dbService.addCollege(_parentIds[ManagementLevel.university]!, data); break;
        case ManagementLevel.department: await _dbService.addDepartment(_parentIds[ManagementLevel.college]!, data); break;
        case ManagementLevel.year: await _dbService.addYear(_parentIds[ManagementLevel.department]!, data); break;
        case ManagementLevel.semester: await _dbService.addSemester(_parentIds[ManagementLevel.year]!, data); break;
        case ManagementLevel.subject: await _dbService.addSubject(_parentIds[ManagementLevel.semester]!, data); break;
        case ManagementLevel.section: 
          data['type'] = name.contains('نظري') ? 'theory' : 'practice';
          await _dbService.addSection(_parentIds[ManagementLevel.subject]!, data); 
          break;
      }
      _showStatusSnackBar('تمت الإضافة بنجاح', isError: false);
    } catch (e) {
      _showStatusSnackBar('فشل الإضافة: $e', isError: true);
    }
  }
}
