import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/home/domain/services/content_service.dart';
import 'package:quizzly/features/home/presentation/screens/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();

  String? _selectedUniversityId;
  String? _selectedCollegeId;
  String? _selectedDepartmentId;

  String _universityName = 'الجامعة';
  String _collegeName = 'الكلية';
  String _departmentName = 'القسم';

  bool _isLoading = false;

  Future<void> _saveAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال الاسم أو اللقب أولاً')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    final contentService = context.read<ContentService>();

    if (authService.user != null) {
      final defaults = {
        'fullName': name,
        if (_selectedUniversityId != null) 'universityId': _selectedUniversityId,
        if (_selectedUniversityId != null) 'universityName': _universityName,
        if (_selectedCollegeId != null) 'collegeId': _selectedCollegeId,
        if (_selectedCollegeId != null) 'collegeName': _collegeName,
        if (_selectedDepartmentId != null) 'departmentId': _selectedDepartmentId,
        if (_selectedDepartmentId != null) 'departmentName': _departmentName,
      };

      await contentService.setUserDefaults(authService.user!.uid, defaults);
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void _skip() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentService = context.read<ContentService>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _skip,
            child: Text(
              'تخطي',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'أهلاً بك في Quizzly!',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'لتقديم تجربة مخصصة لك، نرجو استكمال البيانات التالية:',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Name Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _nameController,
                textAlign: TextAlign.right,
                style: GoogleFonts.cairo(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'الاسم أو اللقب (إجباري)',
                  hintStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Breadcrumbs
            if (_selectedUniversityId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildBreadcrumb('الكل', () {
                        setState(() {
                          _selectedUniversityId = null;
                          _selectedCollegeId = null;
                          _selectedDepartmentId = null;
                        });
                      }),
                      _buildBreadcrumb(_universityName, () {
                        setState(() {
                          _selectedCollegeId = null;
                          _selectedDepartmentId = null;
                        });
                      }),
                      if (_selectedCollegeId != null)
                        _buildBreadcrumb(_collegeName, () {
                          setState(() {
                            _selectedDepartmentId = null;
                          });
                        }),
                      if (_selectedDepartmentId != null)
                        _buildBreadcrumb(_departmentName, () {}),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Hierarchy DrillDown
            Expanded(
              child: _buildDrillDownContent(contentService),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(String label, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildDrillDownContent(ContentService contentService) {
    if (_selectedUniversityId == null) {
      return _buildHierarchyList(
        stream: contentService.getUniversities(),
        title: 'اختر الجامعة',
        onTap: (doc) => setState(() {
          _selectedUniversityId = doc.id;
          final data = doc.data() as Map<String, dynamic>?;
          _universityName = data?['name'] ?? 'الجامعة';
        }),
      );
    }

    if (_selectedCollegeId == null) {
      return _buildHierarchyList(
        stream: contentService.getColleges(_selectedUniversityId!),
        title: 'اختر الكلية',
        onTap: (doc) => setState(() {
          _selectedCollegeId = doc.id;
          final data = doc.data() as Map<String, dynamic>?;
          _collegeName = data?['name'] ?? 'الكلية';
        }),
      );
    }

    if (_selectedDepartmentId == null) {
      return _buildHierarchyList(
        stream: contentService.getDepartments(_selectedCollegeId!),
        title: 'اختر القسم / التخصص',
        onTap: (doc) => setState(() {
          _selectedDepartmentId = doc.id;
          final data = doc.data() as Map<String, dynamic>?;
          _departmentName = data?['name'] ?? 'القسم';
        }),
      );
    }

    // Done selecting everything
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green),
            ),
            const SizedBox(height: 24),
            Text(
              'تم تحديد كافة المعلومات بنجاح!',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'ابدأ الآن',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyList({
    required Stream<QuerySnapshot> stream,
    required String title,
    required Function(QueryDocumentSnapshot) onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data?.docs ?? [];
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'لا توجد خيارات متاحة',
                    style: GoogleFonts.cairo(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final doc = items[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      onTap: () => onTap(doc),
                      title: Text(
                        (doc.data() as Map<String, dynamic>?)?['name']?.toString() ?? 'بدون اسم',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
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
}
