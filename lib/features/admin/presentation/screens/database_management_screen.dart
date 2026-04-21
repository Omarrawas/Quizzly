import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';

enum ManagementLevel { university, college, department, year, semester, subject }

class DatabaseManagementScreen extends StatefulWidget {
  const DatabaseManagementScreen({super.key});

  @override
  State<DatabaseManagementScreen> createState() => _DatabaseManagementScreenState();
}

class _DatabaseManagementScreenState extends State<DatabaseManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  ManagementLevel _currentLevel = ManagementLevel.university;

  // Hierarchical IDs and Names
  String? _uniId, _uniName;
  String? _collegeId, _collegeName;
  String? _deptId, _deptName;
  String? _yearId, _yearName;
  String? _semesterId, _semesterName;

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
    }
  }

  void _goBack() {
    setState(() {
      switch (_currentLevel) {
        case ManagementLevel.college: _currentLevel = ManagementLevel.university; _uniId = null; _uniName = null; break;
        case ManagementLevel.department: _currentLevel = ManagementLevel.college; _collegeId = null; _collegeName = null; break;
        case ManagementLevel.year: _currentLevel = ManagementLevel.department; _deptId = null; _deptName = null; break;
        case ManagementLevel.semester: _currentLevel = ManagementLevel.year; _yearId = null; _yearName = null; break;
        case ManagementLevel.subject: _currentLevel = ManagementLevel.semester; _semesterId = null; _semesterName = null; break;
        default: break;
      }
    });
  }

  Widget _buildBreadcrumbs(bool isDark) {
    List<String> path = [];
    if (_uniName != null) path.add(_uniName!);
    if (_collegeName != null) path.add(_collegeName!);
    if (_deptName != null) path.add(_deptName!);
    if (_yearName != null) path.add(_yearName!);
    if (_semesterName != null) path.add(_semesterName!);

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
      case ManagementLevel.college: stream = _dbService.getColleges(_uniId!); break;
      case ManagementLevel.department: stream = _dbService.getDepartments(_uniId!, _collegeId!); break;
      case ManagementLevel.year: stream = _dbService.getYears(_uniId!, _collegeId!, _deptId!); break;
      case ManagementLevel.semester: stream = _dbService.getSemesters(_uniId!, _collegeId!, _deptId!, _yearId!); break;
      case ManagementLevel.subject: stream = _dbService.getSubjects(_uniId!, _collegeId!, _deptId!, _yearId!, _semesterId!); break;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
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
    
    // Create a local list of paths to update
    final List<String> paths = docs.map((d) => _getCurrentPath(d.id)).toList();
    final item = paths.removeAt(oldIndex);
    paths.insert(newIndex, item);

    // Call batch update in service
    await _dbService.updateOrder(paths);
  }

  void _onItemTap(String id, String name, ManagementLevel fromLevel) {
    setState(() {
      switch (fromLevel) {
        case ManagementLevel.university: _uniId = id; _uniName = name; _currentLevel = ManagementLevel.college; break;
        case ManagementLevel.college: _collegeId = id; _collegeName = name; _currentLevel = ManagementLevel.department; break;
        case ManagementLevel.department: _deptId = id; _deptName = name; _currentLevel = ManagementLevel.year; break;
        case ManagementLevel.year: _yearId = id; _yearName = name; _currentLevel = ManagementLevel.semester; break;
        case ManagementLevel.semester: _semesterId = id; _semesterName = name; _currentLevel = ManagementLevel.subject; break;
        default: break;
      }
    });
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
            IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 22), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22), onPressed: onDelete),
            const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.cairo(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _getCurrentPath(String id) {
    switch (_currentLevel) {
      case ManagementLevel.university: return _dbService.getUniPath(id);
      case ManagementLevel.college: return _dbService.getCollegePath(_uniId!, id);
      case ManagementLevel.department: return _dbService.getDeptPath(_uniId!, _collegeId!, id);
      case ManagementLevel.year: return _dbService.getYearPath(_uniId!, _collegeId!, _deptId!, id);
      case ManagementLevel.semester: return _dbService.getSemesterPath(_uniId!, _collegeId!, _deptId!, _yearId!, id);
      case ManagementLevel.subject: return _dbService.getSubjectPath(_uniId!, _collegeId!, _deptId!, _yearId!, _semesterId!, id);
    }
  }

  void _showEditDialog(String id, Map<String, dynamic> currentData) {
    if (_currentLevel == ManagementLevel.subject) {
      _showSubjectDetailsDialog(id, currentData);
      return;
    }
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
              final path = _getCurrentPath(id);
              final updatedData = {
                'name': nameController.text.trim(),
                if (_currentLevel == ManagementLevel.college) 'subtitle': descController.text.trim()
                else 'description': descController.text.trim(),
              };
              await _dbService.updateDoc(path, updatedData);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('حفظ التغييرات'),
          ),
        ],
      ),
    );
  }

  void _showSubjectDetailsDialog(String id, Map<String, dynamic> data) {
    String selectedType = data['type'] ?? 'theory';
    final nameController = TextEditingController(text: data['name']);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تفاصيل المادة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: 'اسم المادة', labelStyle: GoogleFonts.cairo())),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text('نظري', style: GoogleFonts.cairo()),
                      selected: selectedType == 'theory',
                      onSelected: (val) => setDialogState(() => selectedType = 'theory'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text('عملي', style: GoogleFonts.cairo()),
                      selected: selectedType == 'practice',
                      onSelected: (val) => setDialogState(() => selectedType = 'practice'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final path = _getCurrentPath(id);
                await _dbService.updateDoc(path, {
                  'name': nameController.text.trim(),
                  'type': selectedType,
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت متأكد من حذف ($name)؟\nسيتم حذف جميع البيانات المرتبطة بها نهائياً.', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final path = _getCurrentPath(id);
              await _dbService.deleteDoc(path);
              if (context.mounted) Navigator.pop(context);
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
              await _dbService.addSemester(_uniId!, _collegeId!, _deptId!, _yearId!, {'name': sem});
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
    }
  }

  Future<void> _performAdd(String name, String desc) async {
    switch (_currentLevel) {
      case ManagementLevel.university: await _dbService.addUniversity({'name': name, 'description': desc}); break;
      case ManagementLevel.college: await _dbService.addCollege(_uniId!, {'name': name, 'subtitle': desc}); break;
      case ManagementLevel.department: await _dbService.addDepartment(_uniId!, _collegeId!, {'name': name, 'description': desc}); break;
      case ManagementLevel.year: await _dbService.addYear(_uniId!, _collegeId!, _deptId!, {'name': name, 'description': desc}); break;
      case ManagementLevel.semester: await _dbService.addSemester(_uniId!, _collegeId!, _deptId!, _yearId!, {'name': name, 'description': desc}); break;
      case ManagementLevel.subject: await _dbService.addSubject(_uniId!, _collegeId!, _deptId!, _yearId!, _semesterId!, {'name': name, 'type': 'theory', 'description': desc}); break;
    }
  }
}
