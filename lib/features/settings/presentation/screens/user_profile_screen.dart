import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/home/domain/services/content_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  String? _selectedUniversityId;
  String? _selectedCollegeId;
  String? _selectedDepartmentId;
  String? _selectedYearId;

  String _universityName = '';
  String _collegeName = '';
  String _departmentName = '';
  String _yearName = '';

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = context.read<AuthService>();
    if (authService.user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(authService.user!.uid).get();
      if (doc.exists) {
        final defaults = doc.data()?['defaults'] as Map<String, dynamic>? ?? {};
        setState(() {
          _nameController.text = defaults['fullName'] ?? '';
          _phoneController.text = defaults['phoneNumber'] ?? '';
          
          _selectedUniversityId = defaults['universityId'];
          _selectedCollegeId = defaults['collegeId'];
          _selectedDepartmentId = defaults['departmentId'];
          _selectedYearId = defaults['yearId'];

          _universityName = defaults['universityName'] ?? '';
          _collegeName = defaults['collegeName'] ?? '';
          _departmentName = defaults['departmentName'] ?? '';
          _yearName = defaults['yearName'] ?? '';
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    if (authService.user == null) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'defaults.fullName': _nameController.text.trim(),
        'defaults.phoneNumber': _phoneController.text.trim(),
        'defaults.universityId': _selectedUniversityId,
        'defaults.universityName': _universityName,
        'defaults.collegeId': _selectedCollegeId,
        'defaults.collegeName': _collegeName,
        'defaults.departmentId': _selectedDepartmentId,
        'defaults.departmentName': _departmentName,
        'defaults.yearId': _selectedYearId,
        'defaults.yearName': _yearName,
      };

      await FirebaseFirestore.instance.collection('users').doc(authService.user!.uid).set(
        data,
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث بياناتك بنجاح ✅')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentService = context.read<ContentService>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C14) : const Color(0xFFE5E2DA),
      appBar: AppBar(
        title: Text('بياناتي الشخصية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Avatar Placeholder
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded, size: 50, color: AppColors.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildStatsSection(isDark),
                      const SizedBox(height: 32),

                      _buildSectionTitle('المعلومات الأساسية', isDark),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _nameController,
                        label: 'الاسم الكامل',
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'رقم الهاتف',
                        icon: Icons.phone_android_rounded,
                        isDark: isDark,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 32),
                      
                      _buildSectionTitle('التخصص الدراسي', isDark),
                      const SizedBox(height: 16),
                      
                      // University
                      _buildSelectionTile(
                        label: 'الجامعة',
                        value: _universityName.isEmpty ? 'اختر الجامعة' : _universityName,
                        icon: Icons.account_balance_rounded,
                        onTap: () => _showHierarchyPicker(
                          title: 'اختر الجامعة',
                          stream: contentService.getUniversities(),
                          onSelected: (doc) {
                            setState(() {
                              _selectedUniversityId = doc.id;
                              _universityName = doc['name'];
                              _selectedCollegeId = null;
                              _collegeName = '';
                              _selectedDepartmentId = null;
                              _departmentName = '';
                              _selectedYearId = null;
                              _yearName = '';
                            });
                          },
                          isDark: isDark,
                        ),
                        isDark: isDark,
                      ),
                      
                      if (_selectedUniversityId != null) ...[
                        const SizedBox(height: 12),
                        _buildSelectionTile(
                          label: 'الكلية',
                          value: _collegeName.isEmpty ? 'اختر الكلية' : _collegeName,
                          icon: Icons.school_rounded,
                          onTap: () => _showHierarchyPicker(
                            title: 'اختر الكلية',
                            stream: contentService.getColleges(_selectedUniversityId!),
                            onSelected: (doc) {
                              setState(() {
                                _selectedCollegeId = doc.id;
                                _collegeName = doc['name'];
                                _selectedDepartmentId = null;
                                _departmentName = '';
                                _selectedYearId = null;
                                _yearName = '';
                              });
                            },
                            isDark: isDark,
                          ),
                          isDark: isDark,
                        ),
                      ],

                      if (_selectedCollegeId != null) ...[
                        const SizedBox(height: 12),
                        _buildSelectionTile(
                          label: 'القسم / التخصص',
                          value: _departmentName.isEmpty ? 'اختر القسم' : _departmentName,
                          icon: Icons.category_rounded,
                          onTap: () => _showHierarchyPicker(
                            title: 'اختر القسم',
                            stream: contentService.getDepartments(_selectedCollegeId!),
                            onSelected: (doc) {
                              setState(() {
                                _selectedDepartmentId = doc.id;
                                _departmentName = doc['name'];
                                _selectedYearId = null;
                                _yearName = '';
                              });
                            },
                            isDark: isDark,
                          ),
                          isDark: isDark,
                        ),
                      ],

                      if (_selectedDepartmentId != null) ...[
                        const SizedBox(height: 12),
                        _buildSelectionTile(
                          label: 'السنة الدراسية',
                          value: _yearName.isEmpty ? 'اختر السنة الدراسية' : _yearName,
                          icon: Icons.calendar_today_rounded,
                          onTap: () => _showHierarchyPicker(
                            title: 'اختر السنة',
                            stream: contentService.getYears(_selectedDepartmentId!),
                            onSelected: (doc) {
                              setState(() {
                                _selectedYearId = doc.id;
                                _yearName = doc['name'];
                              });
                            },
                            isDark: isDark,
                          ),
                          isDark: isDark,
                        ),
                      ],

                      const SizedBox(height: 100), // Space for FAB
                    ],
                  ),
                ),
              ),
              if (_isSaving)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
          ),
          child: Text(
            'حفظ البيانات',
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isDark) {
    final authService = context.read<AuthService>();
    final userId = authService.user?.uid;
    if (userId == null) return const SizedBox.shrink();

    final contentService = context.read<ContentService>();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('user_gamification').doc(userId).snapshots(),
      builder: (context, gamificationSnap) {
        int currentStreak = 0;
        if (gamificationSnap.hasData && gamificationSnap.data!.exists) {
          final gData = gamificationSnap.data!.data() as Map<String, dynamic>? ?? {};
          currentStreak = gData['currentStreak'] as int? ?? 0;
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: contentService.getUserActiveSubjects(userId),
          builder: (context, activeSubjectsSnap) {
            if (activeSubjectsSnap.hasError) {
              return _buildStatsCards(isDark, currentStreak, 0.0, 0, hasActiveSubjects: false);
            }

            final activeSubjects = activeSubjectsSnap.data ?? [];
            if (activeSubjects.isEmpty) {
              return _buildStatsCards(isDark, currentStreak, 0.0, 0, hasActiveSubjects: false);
            }

            final activeSubjectIds = activeSubjects.map((s) => s['id'] as String).toList();

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('mastery')
                  .snapshots(),
              builder: (context, masterySnap) {
                final masteredDocs = masterySnap.hasError ? [] : (masterySnap.data?.docs ?? []);
                
                final masteredInActiveSubjects = masteredDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final sId = data['subjectId'] as String?;
                  return sId != null && activeSubjectIds.contains(sId);
                }).length;

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('questions')
                      .where('subjectId', whereIn: activeSubjectIds.take(10).toList())
                      .where('status', isEqualTo: 'approved')
                      .get(),
                  builder: (context, questionsSnap) {
                    final totalQuestions = (questionsSnap.hasError || !questionsSnap.hasData) ? 0 : questionsSnap.data!.size;
                    final progressFraction = totalQuestions > 0 ? (masteredInActiveSubjects / totalQuestions).clamp(0.0, 1.0) : 0.0;

                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('sections')
                          .where('parentId', whereIn: activeSubjectIds.take(10).toList())
                          .get(),
                      builder: (context, sectionsSnap) {
                        final totalSections = (sectionsSnap.hasError || !sectionsSnap.hasData) ? 0 : sectionsSnap.data!.size;
                        int remainingChapters = 0;
                        if (totalSections > 0) {
                          remainingChapters = (totalSections * (1.0 - progressFraction)).round();
                          if (remainingChapters == 0 && progressFraction < 1.0) {
                            remainingChapters = 1;
                          }
                        } else {
                          final fallbackTotal = activeSubjectIds.length * 5;
                          remainingChapters = (fallbackTotal * (1.0 - progressFraction)).round();
                          if (remainingChapters == 0 && progressFraction < 1.0) {
                            remainingChapters = 1;
                          }
                        }

                        return _buildStatsCards(
                          isDark,
                          currentStreak,
                          progressFraction,
                          remainingChapters,
                          hasActiveSubjects: true,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatsCards(
    bool isDark,
    int streak,
    double progressFraction,
    int remainingChapters, {
    bool hasActiveSubjects = true,
  }) {
    final progressPercentage = (progressFraction * 100).toInt();
    
    String remainingText;
    if (!hasActiveSubjects) {
      remainingText = 'لا توجد مواد نشطة حالياً';
    } else if (remainingChapters == 0) {
      remainingText = 'أكملت المنهج بالكامل 🎉';
    } else if (remainingChapters == 1) {
      remainingText = 'بقي فصل واحد فقط';
    } else if (remainingChapters == 2) {
      remainingText = 'بقي فصلين فقط';
    } else if (remainingChapters > 2 && remainingChapters <= 10) {
      remainingText = 'بقي $remainingChapters فصول فقط';
    } else {
      remainingText = 'بقي $remainingChapters فصلاً فقط';
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Row(
          children: [
            // 1. Streak Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A26) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey[200]!,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.02,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Fire Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFEF4444),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Number
                    Text(
                      '$streak',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Text
                    Text(
                      'أيام متتالية',
                      style: GoogleFonts.cairo(
                        color: isDark
                            ? Colors.white60
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 2. Curriculum Completion Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A26) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey[200]!,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.02,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Progress Ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 54,
                          height: 54,
                          child: CircularProgressIndicator(
                            value: progressFraction,
                            strokeWidth: 5.5,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.grey[200]!,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF5F5DFA),
                            ),
                          ),
                        ),
                        Text(
                          '$progressPercentage%',
                          style: GoogleFonts.inter(
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Label Title
                    Text(
                      'إكمال المنهج',
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Subtitle
                    Text(
                      remainingText,
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white54 : Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: GoogleFonts.cairo(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: isDark ? Colors.white60 : Colors.grey),
        prefixIcon: Icon(icon, color: AppColors.primaryBlue),
        filled: true,
        fillColor: isDark ? const Color(0xFF131A26) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A26) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: isDark ? Colors.white38 : Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showHierarchyPicker({
    required String title,
    required Stream<QuerySnapshot> stream,
    required Function(QueryDocumentSnapshot) onSelected,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131A26) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              title,
              style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(child: Text('لا توجد خيارات متاحة حالياً', style: GoogleFonts.cairo()));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return ListTile(
                      title: Text(
                        doc['name'],
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      onTap: () {
                        onSelected(doc);
                        Navigator.pop(context);
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
}
