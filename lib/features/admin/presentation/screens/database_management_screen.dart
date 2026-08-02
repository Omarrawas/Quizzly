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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
            double? basePrice;
            double? finalPrice;
            double? discount = data['discount'] != null ? (data['discount'] as num).toDouble() : null;

            if (_currentLevel == ManagementLevel.subject) {
              basePrice = (data['price'] as num?)?.toDouble();
              if (basePrice != null && discount != null && discount > 0) {
                finalPrice = basePrice * (1 - discount / 100);
              } else {
                finalPrice = basePrice;
              }
            } else if (_currentLevel == ManagementLevel.semester) {
              finalPrice = (data['totalPrice'] as num?)?.toDouble();
              basePrice = (data['manualPrice'] as num?)?.toDouble() ?? (data['basePrice'] as num?)?.toDouble();
              // If basePrice is same as finalPrice (no discount), set basePrice to null to avoid redundant display
              if (basePrice == finalPrice) basePrice = null;
            }

            return _buildManagementCard(
              key: ValueKey(id),
              index: index,
              title: name,
              subtitle: data['description'] ?? data['subtitle'] ?? '',
              basePrice: basePrice,
              finalPrice: finalPrice,
              discount: discount,
              isDark: isDark,
              onTap: () => _onItemTap(id, name, _currentLevel, referenceSubjectId: data['referenceSubjectId']),
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

  void _onItemTap(String id, String name, ManagementLevel fromLevel, {String? referenceSubjectId}) {
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
            referenceSubjectId: referenceSubjectId,
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

  Future<double> _getSemesterSubjectPrices(String semesterId) async {
    final snapshot = await _dbService.getSubjects(semesterId).first;
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['price'] as num?)?.toDouble() ?? 0;
    }
    return total;
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

  Widget _buildManagementCard({
    required Key key, 
    required int index,
    required String title, 
    required String subtitle, 
    double? basePrice,
    double? finalPrice,
    double? discount,
    required bool isDark, 
    required VoidCallback onTap, 
    required VoidCallback onEdit, 
    required VoidCallback onDelete
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (finalPrice != null) ...[
                      if (basePrice != null && basePrice > finalPrice)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '${basePrice.toStringAsFixed(0)} ل.س',
                            style: GoogleFonts.cairo(
                              fontSize: 11, 
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${finalPrice.toStringAsFixed(0)} ل.س',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        ),
                      ),
                    ],
                    if (discount != null && discount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${discount.toStringAsFixed(0)}%',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (_currentLevel == ManagementLevel.section) ...[
                      IconButton(
                        icon: const Icon(Icons.assignment_outlined, color: Colors.purple, size: 22),
                        onPressed: () => _goToExams(
                          _parentIds[ManagementLevel.subject]!,
                          (key as ValueKey<String>).value,
                          title,
                        ),
                        tooltip: 'إدارة الاختبارات',
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(Icons.account_tree_rounded, color: AppColors.primaryBlue, size: 22),
                        onPressed: () => _goToTopics(
                          _parentIds[ManagementLevel.subject]!,
                          (key as ValueKey<String>).value,
                          title,
                        ),
                        tooltip: 'إدارة المواضيع',
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 22),
                      onPressed: onEdit,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                      onPressed: onDelete,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 20),
                      ),
                    ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
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
    if (_currentLevel == ManagementLevel.semester) {
      _showSemesterEditDialog(id, currentData);
      return;
    }
    final nameController = TextEditingController(text: currentData['name']);
    final descController = TextEditingController(text: currentData['description'] ?? currentData['subtitle']);
    String? referenceSubjectId = currentData['referenceSubjectId'];
    List<String> teacherIds = List<String>.from(currentData['teacherIds'] ?? []);
    if (teacherIds.isEmpty && currentData['teacherId'] != null) {
      teacherIds.add(currentData['teacherId']);
    }

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A26) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with Gradient
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryBlue,
                            AppColors.primaryBlue.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.edit_document, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تعديل ${_getAddLabel()}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'تحديث معلومات العنصر في قاعدة البيانات',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPremiumTextField(
                            controller: nameController,
                            label: 'الاسم',
                            icon: Icons.title_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          _buildPremiumTextField(
                            controller: descController,
                            label: 'الوصف',
                            icon: Icons.description_outlined,
                            isDark: isDark,
                            maxLines: 2,
                          ),
                          
                          if (_currentLevel == ManagementLevel.subject) ...[
                            const SizedBox(height: 24),
                            Text(
                              'إدارة المعلمين',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.blue[300] : AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .where('role', isEqualTo: 'teacher')
                                  .get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ));
                                }
                                final allTeachers = snapshot.data!.docs;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (teacherIds.isNotEmpty)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: teacherIds.map((tid) {
                                          final tDoc = allTeachers
                                              .cast<QueryDocumentSnapshot?>()
                                              .firstWhere((doc) => doc?.id == tid, orElse: () => null);
                                          if (tDoc == null) return const SizedBox.shrink();
                                          final tData = tDoc.data() as Map<String, dynamic>;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  tData['defaults']?['fullName'] ?? tData['email'] ?? 'معلم',
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.blue[200] : AppColors.primaryBlue,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () {
                                                    setDialogState(() {
                                                      teacherIds.remove(tid);
                                                      currentData['teacherIds'] = teacherIds;
                                                    });
                                                  },
                                                  child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.blue[200] : AppColors.primaryBlue),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    if (teacherIds.isEmpty)
                                      Text(
                                        'لم يتم تعيين معلمين بعد',
                                        style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                                      ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      decoration: _premiumInputDecoration(
                                        label: 'إضافة معلم',
                                        icon: Icons.person_add_alt_1_rounded,
                                        isDark: isDark,
                                      ),
                                      dropdownColor: isDark ? const Color(0xFF131A26) : Colors.white,
                                      items: allTeachers.where((doc) => !teacherIds.contains(doc.id)).map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        return DropdownMenuItem<String>(
                                          value: doc.id,
                                          child: Text(
                                            data['defaults']?['fullName'] ?? data['email'] ?? 'معلم',
                                            style: GoogleFonts.cairo(fontSize: 13),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() {
                                            teacherIds.add(val);
                                            currentData['teacherIds'] = teacherIds;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPremiumTextField(
                                    controller: TextEditingController(text: currentData['price']?.toString() ?? ''),
                                    label: 'السعر (ل.س)',
                                    icon: Icons.payments_outlined,
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => currentData['price'] = double.tryParse(v),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildPremiumTextField(
                                    controller: TextEditingController(text: currentData['discount']?.toString() ?? ''),
                                    label: 'الخصم (%)',
                                    icon: Icons.percent_rounded,
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => currentData['discount'] = double.tryParse(v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance.collection('subjects').get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox.shrink();
                                
                                final masterSubjects = snapshot.data!.docs.where((doc) {
                                  if (doc.id == id) return false;
                                  final data = doc.data() as Map<String, dynamic>;
                                  return data['referenceSubjectId'] == null;
                                }).toList();

                                return DropdownButtonFormField<String?>(
                                  initialValue: referenceSubjectId,
                                  decoration: _premiumInputDecoration(
                                    label: 'ربط المحتوى بمادة أخرى',
                                    icon: Icons.link_rounded,
                                    isDark: isDark,
                                  ),
                                  dropdownColor: isDark ? const Color(0xFF131A26) : Colors.white,
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('مادة رئيسية (لا يوجد ربط)', style: GoogleFonts.cairo(fontSize: 13)),
                                    ),
                                    ...masterSubjects.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      return DropdownMenuItem<String?>(
                                        value: doc.id,
                                        child: Text(data['name'] ?? '', style: GoogleFonts.cairo(fontSize: 13)),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    setDialogState(() {
                                      referenceSubjectId = val;
                                    });
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'إلغاء',
                                style: GoogleFonts.cairo(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  final updatedData = {
                                    'name': nameController.text.trim(),
                                    if (_currentLevel == ManagementLevel.college) 'subtitle': descController.text.trim()
                                    else 'description': descController.text.trim(),
                                    if (_currentLevel == ManagementLevel.subject || _currentLevel == ManagementLevel.semester) ...{
                                      'price': currentData['price'],
                                      'discount': currentData['discount'],
                                      if (_currentLevel == ManagementLevel.semester) 'totalPrice': currentData['totalPrice'],
                                    },
                                    if (_currentLevel == ManagementLevel.subject) ...{
                                      'referenceSubjectId': referenceSubjectId,
                                      'teacherIds': teacherIds,
                                      'teacherId': teacherIds.isNotEmpty ? teacherIds.first : null,
                                    },
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text(
                                  'حفظ التغييرات',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _premiumInputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(
        color: isDark ? Colors.white60 : AppColors.textSecondary,
        fontSize: 14,
      ),
      floatingLabelStyle: GoogleFonts.cairo(
        color: AppColors.primaryBlue,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 20),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: GoogleFonts.cairo(
        fontSize: 14,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
      decoration: _premiumInputDecoration(label: label, icon: icon, isDark: isDark),
    );
  }

  void _showSemesterEditDialog(String id, Map<String, dynamic> currentData) async {
    final nameController = TextEditingController(text: currentData['name']);
    final descController = TextEditingController(text: currentData['description'] ?? '');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final totalPrice = await _getSemesterSubjectPrices(id);
    if (!mounted) return;
    Navigator.pop(context); // Close loading

    double discount = (currentData['discount'] as num?)?.toDouble() ?? 0;
    double? manualPrice = (currentData['manualPrice'] as num?)?.toDouble();

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final effectiveBasePrice = manualPrice ?? totalPrice;
            final finalPrice = effectiveBasePrice * (1 - (discount / 100));
            
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A26) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.primaryBlue, Color(0xFF7C3AED)]),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 30),
                            const SizedBox(width: 16),
                            Text('تعديل الفصل الدراسي', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildPremiumTextField(controller: nameController, label: 'الاسم', icon: Icons.title, isDark: isDark),
                            const SizedBox(height: 16),
                            _buildPremiumTextField(controller: descController, label: 'الوصف', icon: Icons.description, isDark: isDark),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('مجموع أسعار المواد:', style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey)),
                                      Text('${totalPrice.toStringAsFixed(0)} ل.س', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPremiumTextField(
                                    controller: TextEditingController(text: manualPrice?.toStringAsFixed(0) ?? ''),
                                    label: 'سعر يدوي للفصل (اختياري)',
                                    icon: Icons.edit_attributes_rounded,
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => setDialogState(() => manualPrice = double.tryParse(v)),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPremiumTextField(
                                    controller: TextEditingController(text: discount.toStringAsFixed(0)),
                                    label: 'خصم الفصل (%)',
                                    icon: Icons.percent_rounded,
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => setDialogState(() => discount = double.tryParse(v) ?? 0),
                                  ),
                                  const Divider(height: 32),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('السعر النهائي:', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                                      Text('${finalPrice.toStringAsFixed(0)} ل.س', style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء'))),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final updatedData = {
                                    'name': nameController.text.trim(),
                                    'description': descController.text.trim(),
                                    'totalPrice': finalPrice, 
                                    'basePrice': totalPrice,  
                                    'manualPrice': manualPrice,
                                    'discount': discount,
                                  };
                                  try {
                                    await _dbService.updateDoc(DatabaseService.colSemesters, id, updatedData);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _showStatusSnackBar('تم التعديل بنجاح', isError: false);
                                    }
                                  } catch (e) {
                                    if (context.mounted) _showStatusSnackBar('فشل التعديل: $e', isError: true);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text('حفظ التغييرات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
    double? price;
    double? discount;
    String? referenceSubjectId;
    List<String> teacherIds = [];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A26) : Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_rounded, color: Colors.white, size: 30),
                          const SizedBox(width: 16),
                          Text('إضافة ${_getAddLabel()} جديد', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildPremiumTextField(controller: nameController, label: 'الاسم', icon: Icons.title, isDark: isDark),
                          const SizedBox(height: 16),
                          _buildPremiumTextField(controller: descController, label: 'الوصف (اختياري)', icon: Icons.description, isDark: isDark),
                          
                          if (_currentLevel == ManagementLevel.subject) ...[
                            const SizedBox(height: 24),
                            FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const CircularProgressIndicator();
                                final allTeachers = snapshot.data!.docs;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (teacherIds.isNotEmpty)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: teacherIds.map((tid) {
                                          final tDoc = allTeachers.cast<QueryDocumentSnapshot?>().firstWhere((doc) => doc?.id == tid, orElse: () => null);
                                          if (tDoc == null) return const SizedBox.shrink();
                                          final tData = tDoc.data() as Map<String, dynamic>;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(tData['defaults']?['fullName'] ?? tData['email'] ?? 'معلم', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                                                const SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () => setDialogState(() => teacherIds.remove(tid)),
                                                  child: const Icon(Icons.close, size: 14),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      decoration: _premiumInputDecoration(label: 'إضافة معلم', icon: Icons.person_add, isDark: isDark),
                                      dropdownColor: isDark ? const Color(0xFF131A26) : Colors.white,
                                      items: allTeachers.where((doc) => !teacherIds.contains(doc.id)).map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        return DropdownMenuItem<String>(
                                          value: doc.id,
                                          child: Text(data['defaults']?['fullName'] ?? data['email'] ?? 'معلم', style: GoogleFonts.cairo(fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setDialogState(() => teacherIds.add(val));
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPremiumTextField(
                                    controller: TextEditingController(),
                                    label: 'السعر',
                                    icon: Icons.payments,
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => price = double.tryParse(v),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildPremiumTextField(
                                    controller: TextEditingController(),
                                    label: 'الخصم',
                                    icon: Icons.percent,
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => discount = double.tryParse(v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance.collection('subjects').get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox.shrink();
                                final masterSubjects = snapshot.data!.docs.where((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  return data['referenceSubjectId'] == null;
                                }).toList();

                                return DropdownButtonFormField<String?>(
                                  decoration: _premiumInputDecoration(label: 'ربط بمادة أخرى', icon: Icons.link, isDark: isDark),
                                  dropdownColor: isDark ? const Color(0xFF131A26) : Colors.white,
                                  items: [
                                    DropdownMenuItem<String?>(value: null, child: Text('لا يوجد ربط', style: GoogleFonts.cairo(fontSize: 13))),
                                    ...masterSubjects.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      return DropdownMenuItem<String?>(value: doc.id, child: Text(data['name'] ?? '', style: GoogleFonts.cairo(fontSize: 13)));
                                    }),
                                  ],
                                  onChanged: (val) => setDialogState(() => referenceSubjectId = val),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء'))),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                final name = nameController.text.trim();
                                if (name.isNotEmpty) {
                                  await _performAdd(name, descController.text.trim(), price: price, discount: discount, referenceSubjectId: referenceSubjectId, teacherIds: teacherIds);
                                  if (context.mounted) Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('إضافة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

  Future<void> _performAdd(String name, String desc, {double? price, double? discount, String? referenceSubjectId, List<String>? teacherIds}) async {
    final Map<String, dynamic> data = {
      'name': name,
      _currentLevel == ManagementLevel.college ? 'subtitle' : 'description': desc,
      if (_currentLevel == ManagementLevel.subject) ...{
        'price': price,
        'discount': discount,
        'referenceSubjectId': referenceSubjectId,
        'teacherIds': teacherIds,
        'teacherId': (teacherIds != null && teacherIds.isNotEmpty) ? teacherIds.first : null,
      },
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
