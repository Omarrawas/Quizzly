import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/home/domain/services/content_service.dart';

class SubjectSelectionScreen extends StatefulWidget {
  const SubjectSelectionScreen({super.key});

  @override
  State<SubjectSelectionScreen> createState() => _SubjectSelectionScreenState();
}

class _SubjectSelectionScreenState extends State<SubjectSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  String? _selectedUniversityId;
  String? _selectedCollegeId;
  String? _selectedDepartmentId;
  String? _selectedYearId;

  String _universityName = 'الجامعة';
  String _collegeName = 'الكلية';
  String _departmentName = 'القسم';
  String _yearName = 'السنة';

  @override
  void initState() {
    super.initState();
    _loadUserDefaults();
  }

  Future<void> _loadUserDefaults() async {
    final authService = context.read<AuthService>();
    final contentService = context.read<ContentService>();
    if (authService.user != null) {
      final defaults = await contentService.getUserDefaults(authService.user!.uid);
      if (defaults != null) {
        setState(() {
          _selectedUniversityId = defaults['universityId'];
          _selectedCollegeId = defaults['collegeId'];
          _selectedDepartmentId = defaults['departmentId'];
          _selectedYearId = defaults['yearId'];
          
          _universityName = defaults['universityName'] ?? 'الجامعة';
          _collegeName = defaults['collegeName'] ?? 'الكلية';
          _departmentName = defaults['departmentName'] ?? 'القسم';
          _yearName = defaults['yearName'] ?? 'السنة';
        });
      }
    }
  }

  Future<void> _saveAsDefault() async {
    final authService = context.read<AuthService>();
    final contentService = context.read<ContentService>();
    if (authService.user != null && _selectedUniversityId != null) {
      await contentService.setUserDefaults(authService.user!.uid, {
        'universityId': _selectedUniversityId,
        'collegeId': _selectedCollegeId,
        'departmentId': _selectedDepartmentId,
        'yearId': _selectedYearId,
        'universityName': _universityName,
        'collegeName': _collegeName,
        'departmentName': _departmentName,
        'yearName': _yearName,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الخيارات كإعدادات افتراضية بنجاح ✅'), backgroundColor: Colors.green),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedUniversityId = null;
      _selectedCollegeId = null;
      _selectedDepartmentId = null;
      _selectedYearId = null;
      
      _universityName = 'الجامعة';
      _collegeName = 'الكلية';
      _departmentName = 'القسم';
      _yearName = 'السنة';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentService = context.read<ContentService>();
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'تصفح المواد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_selectedUniversityId != null)
            IconButton(
              onPressed: _saveAsDefault,
              icon: const Icon(Icons.bookmark_added_rounded),
              tooltip: 'حفظ كإفتراضي',
            ),
          IconButton(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'إعادة ضبط',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.right,
                style: GoogleFonts.cairo(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'ابحث عن مادة محددة...',
                  hintStyle: GoogleFonts.cairo(
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // 2. Breadcrumbs / Selected Path (Optional visual aid)
          if (_selectedUniversityId != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildBreadcrumb('الكل', () => _resetFilters()),
                  _buildBreadcrumb(_universityName, () {
                    setState(() {
                      _selectedCollegeId = null;
                      _collegeName = 'الكلية';
                      _selectedDepartmentId = null;
                      _departmentName = 'القسم';
                      _selectedYearId = null;
                      _yearName = 'السنة';
                    });
                  }),
                  if (_selectedCollegeId != null)
                    _buildBreadcrumb(_collegeName, () {
                      setState(() {
                        _selectedDepartmentId = null;
                        _departmentName = 'القسم';
                        _selectedYearId = null;
                        _yearName = 'السنة';
                      });
                    }),
                  if (_selectedDepartmentId != null)
                    _buildBreadcrumb(_departmentName, () {
                      setState(() {
                        _selectedYearId = null;
                        _yearName = 'السنة';
                      });
                    }),
                  if (_selectedYearId != null)
                    _buildBreadcrumb(_yearName, () {}),
                ],
              ),
            ),

          const Divider(height: 24, thickness: 0.5),

          // 3. Main Discovery Area
          Expanded(
            child: authService.user == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<Set<String>>(
                    stream: contentService.getUserActiveSubjectIds(authService.user!.uid),
                    builder: (context, activeSnapshot) {
                      final activeIds = activeSnapshot.data ?? {};
                      
                      return _buildDrillDownContent(contentService, activeIds);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.primaryBlue)),
            const Icon(Icons.chevron_left_rounded, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildDrillDownContent(ContentService contentService, Set<String> activeIds) {
    if (_selectedUniversityId == null) {
      return _buildHierarchyList(
        stream: contentService.getUniversities(),
        title: 'اختر الجامعة',
        onTap: (doc) => setState(() {
          _selectedUniversityId = doc.id;
          _universityName = doc['name'];
        }),
      );
    }

    if (_selectedCollegeId == null) {
      return _buildHierarchyList(
        stream: contentService.getColleges(_selectedUniversityId!),
        title: 'اختر الكلية',
        onTap: (doc) => setState(() {
          _selectedCollegeId = doc.id;
          _collegeName = doc['name'];
        }),
      );
    }

    if (_selectedDepartmentId == null) {
      return _buildHierarchyList(
        stream: contentService.getDepartments(_selectedCollegeId!),
        title: 'اختر القسم / التخصص',
        onTap: (doc) => setState(() {
          _selectedDepartmentId = doc.id;
          _departmentName = doc['name'];
        }),
      );
    }

    if (_selectedYearId == null) {
      return _buildHierarchyList(
        stream: contentService.getYears(_selectedDepartmentId!),
        title: 'اختر السنة الدراسية',
        onTap: (doc) => setState(() {
          _selectedYearId = doc.id;
          _yearName = doc['name'];
        }),
      );
    }

    // Final Level: Semesters & Subjects
    return StreamBuilder<QuerySnapshot>(
      stream: contentService.getSemesters(_selectedYearId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final semesters = snapshot.data?.docs ?? [];
        if (semesters.isEmpty) return _buildEmptyState('لا توجد فصول دراسية مضافة لهذه السنة بعد.');

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: semesters.length,
          itemBuilder: (context, index) {
            final semDoc = semesters[index];
            return _SemesterCard(
              semesterId: semDoc.id,
              semesterName: semDoc['name'],
              contentService: contentService,
              activeSubjectIds: activeIds,
            );
          },
        );
      },
    );
  }

  Widget _buildHierarchyList({
    required Stream<QuerySnapshot> stream,
    required String title,
    required Function(QueryDocumentSnapshot) onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data?.docs ?? [];
              if (items.isEmpty) return _buildEmptyState('لا توجد بيانات متاحة حالياً.');

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final doc = items[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
                    ),
                    child: ListTile(
                      onTap: () => onTap(doc),
                      title: Text(doc['name'], style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.primaryBlue),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_rounded, size: 64, color: AppColors.primaryBlue.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemesterCard extends StatelessWidget {
  final String semesterId;
  final String semesterName;
  final ContentService contentService;
  final Set<String> activeSubjectIds;

  const _SemesterCard({
    required this.semesterId,
    required this.semesterName,
    required this.contentService,
    required this.activeSubjectIds,
  });

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : AppColors.primaryBlue.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded, color: AppColors.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(semesterName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _addFullSemester(context, authService.user?.uid),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.add_task_rounded, size: 16),
                  label: Text('إضافة الكل', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // Subjects List
          StreamBuilder<QuerySnapshot>(
            stream: contentService.getSubjects(semesterId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              final subjects = snapshot.data?.docs ?? [];
              if (subjects.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('لا توجد مواد في هذا الفصل', style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary)),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: subjects.map((subj) {
                    final isAdded = activeSubjectIds.contains(subj.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(subj['name'], style: GoogleFonts.cairo(fontSize: 14, fontWeight: isAdded ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text('كود: ${subj['code']}', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
                      trailing: isAdded
                        ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24)
                        : TextButton.icon(
                            onPressed: () => _addSubject(context, authService.user?.uid, subj.id),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                            label: Text('إضافة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addFullSemester(BuildContext context, String? userId) async {
    if (userId == null) return;
    try {
      await contentService.addUserSemester(userId, semesterId);
      if (!context.mounted) return;
      _showSuccess(context, 'تم إضافة الفصل بالكامل للرئيسية ✅');
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'حدث خطأ أثناء الإضافة');
    }
  }

  Future<void> _addSubject(BuildContext context, String? userId, String subjectId) async {
    if (userId == null) return;
    try {
      await contentService.addUserSubject(userId, subjectId);
      if (!context.mounted) return;
      _showSuccess(context, 'تم إضافة المادة للرئيسية ✅');
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'حدث خطأ أثناء الإضافة');
    }
  }

  void _showSuccess(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo()),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo()),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}
