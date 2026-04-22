import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/home/data/models/college_model.dart';
import 'package:quizzly/features/home/domain/services/college_service.dart';

class SubjectSelectionScreen extends StatefulWidget {
  const SubjectSelectionScreen({super.key});

  @override
  State<SubjectSelectionScreen> createState() => _SubjectSelectionScreenState();
}

class _SubjectSelectionScreenState extends State<SubjectSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedUniversity = 'الجامعة';
  String _selectedCollege = 'الكلية';
  String _selectedSemester = 'الفصل';
  String _selectedSubject = 'المادة';
  bool _isAllSelected = true;

  final List<String> _universities = [
    'جامعة دمشق',
    'جامعة حلب',
    'جامعة تشرين',
    'جامعة البعث',
  ];
  final List<String> _colleges = [
    'الهندسة المعلوماتية',
    'الطب البشري',
    'الصيدلة',
    'الهندسة المدنية',
  ];
  final List<String> _semesters = [
    'الفصل الأول',
    'الفصل الثاني',
    'الفصل الثالث (تكميلي)',
  ];
  final List<String> _subjects = ['رياضيات', 'برمجة', 'قواعد بيانات', 'شبكات'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedUniversity = 'الجامعة';
      _selectedCollege = 'الكلية';
      _selectedSemester = 'الفصل';
      _selectedSubject = 'المادة';
      _isAllSelected = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'اختيار المواد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
                  hintText: 'ابحث عن مادة...',
                  hintStyle: GoogleFonts.cairo(
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // 2. Filters List
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFilterChip(
                  label: 'الكل',
                  isSelected: _isAllSelected,
                  onTap: _resetFilters,
                ),
                _buildDropdownFilterChip(
                  label: _selectedUniversity,
                  items: _universities,
                  onSelected: (val) => setState(() {
                    _selectedUniversity = val;
                    _isAllSelected = false;
                  }),
                  isActive: _selectedUniversity != 'الجامعة',
                ),
                _buildDropdownFilterChip(
                  label: _selectedCollege,
                  items: _colleges,
                  onSelected: (val) => setState(() {
                    _selectedCollege = val;
                    _isAllSelected = false;
                  }),
                  isActive: _selectedCollege != 'الكلية',
                ),
                _buildDropdownFilterChip(
                  label: _selectedSemester,
                  items: _semesters,
                  onSelected: (val) => setState(() {
                    _selectedSemester = val;
                    _isAllSelected = false;
                  }),
                  isActive: _selectedSemester != 'الفصل',
                ),
                _buildDropdownFilterChip(
                  label: _selectedSubject,
                  items: _subjects,
                  onSelected: (val) => setState(() {
                    _selectedSubject = val;
                    _isAllSelected = false;
                  }),
                  isActive: _selectedSubject != 'المادة',
                ),
              ],
            ),
          ),

          const Divider(height: 32, thickness: 0.5),

          // 3. Main Content
          Expanded(
            child: StreamBuilder<List<CollegeModel>>(
              stream: context.read<CollegeService>().getAvailableColleges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final colleges = snapshot.data ?? [];

                if (colleges.isEmpty) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        Icon(
                          Icons.library_books_outlined,
                          size: 80,
                          color: AppColors.primaryBlue.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'لا يوجد مواد متاحة حالياً',
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'سيتم تقديم قائمة بالمواد المتاحة للتصفح التجريبي قريباً.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: colleges.length,
                  itemBuilder: (context, index) {
                    final college = colleges[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryBlue.withValues(
                            alpha: 0.1,
                          ),
                          child: Icon(
                            college.icon,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        title: Text(
                          college.name,
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          college.subtitle,
                          style: GoogleFonts.cairo(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () {},
                      ),
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

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
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
          side: BorderSide(
            color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownFilterChip({
    required String label,
    required List<String> items,
    required Function(String) onSelected,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PopupMenuButton<String>(
        onSelected: onSelected,
        itemBuilder: (context) => items
            .map(
              (item) => PopupMenuItem<String>(
                value: item,
                child: Text(item, style: GoogleFonts.cairo(fontSize: 14)),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? AppColors.primaryBlue : AppColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
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
