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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // 1. Modern Header / App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            centerTitle: true,
            title: Text(
              'تصفح المواد',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            actions: [
              if (_selectedUniversityId != null)
                IconButton(
                  onPressed: _saveAsDefault,
                  icon: const Icon(Icons.bookmark_added_rounded),
                  tooltip: 'حفظ كإفتراضي',
                ),
              IconButton(
                onPressed: () => _showAddCodeDialog(contentService, authService.user?.uid),
                icon: const Icon(Icons.vpn_key_rounded, color: AppColors.primaryBlue),
                tooltip: 'تفعيل بواسطة كود',
              ),
              IconButton(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'إعادة ضبط',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: isDark 
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [Colors.white, const Color(0xFFF1F6FF)],
                  ),
                ),
              ),
            ),
          ),

          // 2. Search & Breadcrumbs Section
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),
                ),

                // Breadcrumbs
                if (_selectedUniversityId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _buildBreadcrumb('الكل', () => _resetFilters(), isFirst: true),
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
                            _buildBreadcrumb(_yearName, () {}, isLast: true),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 10),
              ],
            ),
          ),

          // 3. Content Area
          SliverFillRemaining(
            hasScrollBody: true,
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

  Widget _buildBreadcrumb(String label, VoidCallback onTap, {bool isFirst = false, bool isLast = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isLast ? AppColors.primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isFirst) 
              const Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.textSecondary),
            Text(
              label, 
              style: GoogleFonts.cairo(
                fontSize: 13, 
                fontWeight: isLast ? FontWeight.bold : FontWeight.w600,
                color: isLast ? AppColors.primaryBlue : AppColors.textSecondary,
              ),
            ),
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

  Widget _buildEmptyState(String message, {bool showCodeAction = true}) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.library_books_rounded, size: 64, color: AppColors.primaryBlue.withValues(alpha: 0.3)),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'قد لا تكون المواد مضافة لهذا العام الدراسي بعد في قاعدة البيانات.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
              ),
              if (showCodeAction) ...[
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _showAddCodeDialog(
                    context.read<ContentService>(), 
                    context.read<AuthService>().user?.uid
                  ),
                  icon: const Icon(Icons.vpn_key_rounded),
                  label: Text('تفعيل مادة بواسطة كود', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCodeDialog(ContentService contentService, String? userId) {
    if (userId == null) return;
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تفعيل مادة / فصل', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أدخل الكود الخاص بالمادة أو الفصل الدراسي لتفعيله مباشرة',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              textAlign: TextAlign.center,
              autofocus: true,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'ABCD-1234',
                hintStyle: GoogleFonts.inter(color: Colors.grey[300]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text;
              if (code.isEmpty) return;
              
              Navigator.pop(context);
              _processCode(contentService, userId, code);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('تفعيل الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _processCode(ContentService contentService, String userId, String code) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await contentService.resolveContentCode(code);
      if (!mounted) return;
      Navigator.pop(context); // hide loading

      if (result == null) {
        _showErrorDialog('الكود غير صحيح أو منتهي الصلاحية ❌');
        return;
      }

      final String type = result['type'];
      final String targetId = result['targetId'];
      final String name = result['name'];

      if (type == 'semester') {
        await contentService.addUserSemester(userId, targetId);
        _showSuccessSnackBar('تم تفعيل فصل "$name" بنجاح ✅');
      } else {
        await contentService.addUserSubject(userId, targetId);
        _showSuccessSnackBar('تم تفعيل مادة "$name" بنجاح ✅');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // hide loading
      _showErrorDialog('حدث خطأ أثناء معالجة الكود');
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('خطأ', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('حسناً', style: GoogleFonts.cairo())),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo()),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.primaryBlue).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                  ? [const Color(0xFF334155), const Color(0xFF1E293B)]
                  : [AppColors.primaryBlue.withValues(alpha: 0.1), AppColors.primaryBlue.withValues(alpha: 0.02)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: AppColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    semesterName,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : AppColors.primaryBlue,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addFullSemester(context, authService.user?.uid),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.library_add_rounded, size: 18, color: AppColors.primaryBlue),
                  label: Text(
                    'تفعيل الكل',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Subjects List
          StreamBuilder<QuerySnapshot>(
            stream: contentService.getSubjects(semesterId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final subjects = snapshot.data?.docs ?? [];
              if (subjects.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'لا توجد مواد مضافة بعد',
                      style: GoogleFonts.cairo(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: subjects.map((subj) {
                    final isAdded = activeSubjectIds.contains(subj.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isAdded 
                          ? AppColors.primaryBlue.withValues(alpha: isDark ? 0.2 : 0.05)
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isAdded 
                            ? AppColors.primaryBlue.withValues(alpha: 0.3)
                            : Colors.transparent,
                        ),
                      ),
                      child: ListTile(
                        onTap: isAdded ? null : () => _addSubject(context, authService.user?.uid, subj.id),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: CircleAvatar(
                          backgroundColor: isAdded ? AppColors.primaryBlue : AppColors.borderLight,
                          radius: 18,
                          child: Text(
                            subj['name'].substring(0, 1),
                            style: GoogleFonts.cairo(
                              color: isAdded ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          subj['name'],
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: isAdded ? FontWeight.bold : FontWeight.w500,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'كود المادة: ${subj['code']}',
                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: isAdded
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'مفعلة',
                                    style: GoogleFonts.cairo(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () => _addSubject(context, authService.user?.uid, subj.id),
                                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
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
      _showSuccess(context, 'تم تفعيل الفصل بالكامل بنجاح ✅');
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'حدث خطأ أثناء التفعيل');
    }
  }

  void _addSubject(BuildContext context, String? userId, String subjectId) async {
    if (userId == null) return;
    try {
      await contentService.addUserSubject(userId, subjectId);
      if (!context.mounted) return;
      _showSuccess(context, 'تم تفعيل المادة بنجاح ✨');
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'حدث خطأ أثناء التفعيل');
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
