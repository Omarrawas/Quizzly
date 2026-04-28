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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الخيارات كإعدادات افتراضية بنجاح ✅'), backgroundColor: Colors.green),
        );
      }
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

          // 2. Dynamic Filters
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFilterChip(
                  label: 'الكل',
                  isSelected: _selectedUniversityId == null,
                  onTap: _resetFilters,
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: contentService.getUniversities(),
                  builder: (context, snapshot) {
                    final items = snapshot.data?.docs ?? [];
                    return _buildDropdownFilterChip(
                      label: _universityName,
                      items: items,
                      onSelected: (id, name) {
                        setState(() {
                          _selectedUniversityId = id;
                          _universityName = name;
                          _selectedCollegeId = null;
                          _collegeName = 'الكلية';
                          _selectedDepartmentId = null;
                          _departmentName = 'القسم';
                        });
                      },
                      isActive: _selectedUniversityId != null,
                    );
                  }
                ),
                if (_selectedUniversityId != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: contentService.getColleges(_selectedUniversityId!),
                    builder: (context, snapshot) {
                      final items = snapshot.data?.docs ?? [];
                      return _buildDropdownFilterChip(
                        label: _collegeName,
                        items: items,
                        onSelected: (id, name) {
                          setState(() {
                            _selectedCollegeId = id;
                            _collegeName = name;
                            _selectedDepartmentId = null;
                            _departmentName = 'القسم';
                          });
                        },
                        isActive: _selectedCollegeId != null,
                      );
                    }
                  ),
                if (_selectedCollegeId != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: contentService.getDepartments(_selectedCollegeId!),
                    builder: (context, snapshot) {
                      final items = snapshot.data?.docs ?? [];
                      return _buildDropdownFilterChip(
                        label: _departmentName,
                        items: items,
                        onSelected: (id, name) {
                          setState(() {
                            _selectedDepartmentId = id;
                            _departmentName = name;
                            _selectedYearId = null;
                            _yearName = 'السنة';
                          });
                        },
                        isActive: _selectedDepartmentId != null,
                      );
                    }
                  ),
                if (_selectedDepartmentId != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: contentService.getYears(_selectedDepartmentId!),
                    builder: (context, snapshot) {
                      final items = snapshot.data?.docs ?? [];
                      return _buildDropdownFilterChip(
                        label: _yearName,
                        items: items,
                        onSelected: (id, name) {
                          setState(() {
                            _selectedYearId = id;
                            _yearName = name;
                          });
                        },
                        isActive: _selectedYearId != null,
                      );
                    }
                  ),
              ],
            ),
          ),

          const Divider(height: 32, thickness: 0.5),

          // 3. Main Content
          Expanded(
            child: authService.user == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<Set<String>>(
                    stream: contentService.getUserActiveSubjectIds(authService.user!.uid),
                    builder: (context, activeSnapshot) {
                      final activeIds = activeSnapshot.data ?? {};
                      
                      return _selectedYearId == null
                          ? _buildEmptyState('يرجى اختيار التخصص والسنة الدراسية لعرض الفصول والمواد المتاحة.')
                          : StreamBuilder<QuerySnapshot>(
                              stream: contentService.getSemesters(_selectedYearId!),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                final semesters = snapshot.data?.docs ?? [];
                                if (semesters.isEmpty) return _buildEmptyState('لا توجد فصول دراسية مضافة لهذه السنة بعد.');

                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: semesters.length,
                                  itemBuilder: (context, index) {
                                    final semDoc = semesters[index];
                                    return _SemesterExpansionTile(
                                      semesterId: semDoc.id,
                                      semesterName: semDoc['name'],
                                      contentService: contentService,
                                      activeSubjectIds: activeIds,
                                    );
                                  },
                                );
                              },
                            );
                    },
                  ),
          ),
        ],
      ),
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

  Widget _buildFilterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        labelStyle: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.primaryBlue,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isSelected ? AppColors.primaryBlue : AppColors.borderLight),
        ),
      ),
    );
  }

  Widget _buildDropdownFilterChip({
    required String label,
    required List<QueryDocumentSnapshot> items,
    required Function(String, String) onSelected,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PopupMenuButton<Map<String, String>>(
        onSelected: (val) => onSelected(val['id']!, val['name']!),
        itemBuilder: (context) => items.map((doc) => PopupMenuItem<Map<String, String>>(
          value: {'id': doc.id, 'name': doc['name']},
          child: Text(doc['name'], style: GoogleFonts.cairo(fontSize: 14)),
        )).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? AppColors.primaryBlue : AppColors.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isActive ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SemesterExpansionTile extends StatelessWidget {
  final String semesterId;
  final String semesterName;
  final ContentService contentService;
  final Set<String> activeSubjectIds;

  const _SemesterExpansionTile({
    required this.semesterId,
    required this.semesterName,
    required this.contentService,
    required this.activeSubjectIds,
  });

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        title: Text(semesterName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: const Icon(Icons.folder_open_rounded, color: AppColors.primaryBlue),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        trailing: ElevatedButton(
          onPressed: () => _addFullSemester(context, authService.user?.uid),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text('إضافة الكل', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: contentService.getSubjects(semesterId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              final subjects = snapshot.data?.docs ?? [];
              if (subjects.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('لا توجد مواد في هذا الفصل', style: GoogleFonts.cairo(fontSize: 12)),
                );
              }

              return Column(
                children: subjects.map((subj) {
                  final isAdded = activeSubjectIds.contains(subj.id);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(subj['name'], style: GoogleFonts.cairo(fontSize: 14, fontWeight: isAdded ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('كود: ${subj['code']}', style: GoogleFonts.cairo(fontSize: 11)),
                    trailing: isAdded
                      ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24)
                      : TextButton.icon(
                          onPressed: () => _addSubject(context, authService.user?.uid, subj.id),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: Text('إضافة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        ),
                  );
                }).toList(),
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
