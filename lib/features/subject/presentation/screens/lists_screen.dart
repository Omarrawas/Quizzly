import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/data/models/exam_models.dart';
import 'package:quizzly/features/subject/presentation/widgets/list_tiles.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/screens/quiz_screen.dart';

class ExamsListScreen extends StatefulWidget {
  final String subjectName;

  const ExamsListScreen({
    super.key,
    this.subjectName = 'الكيمياء',
  });

  @override
  State<ExamsListScreen> createState() => _ExamsListScreenState();
}

class _ExamsListScreenState extends State<ExamsListScreen> {
  final List<ExamItem> _exams = mockExams;
  int _selectedFilter = 0;

  final List<String> _filters = [
    'الدورات الوزارية',
    'التجريبية',
    'الكل',
  ];

  List<ExamItem> get _filtered => _selectedFilter == 2
      ? _exams
      : _selectedFilter == 1
          ? _exams.where((e) => e.title.contains('التجريبية')).toList()
          : _exams.where((e) => !e.title.contains('التجريبية')).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter chips
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemCount: _filters.length,
              itemBuilder: (context, i) => _FilterChip(
                label: _filters[i],
                isSelected: _selectedFilter == i,
                onTap: () => setState(() => _selectedFilter = i),
              ),
            ),
          ),
          // ── List
          Expanded(
            child: _filtered.isEmpty
                ? _EmptyState(message: 'لا توجد امتحانات في هذه الفئة')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) => ExamListTile(
                      exam: _filtered[index],
                      onTap: () {
                        if (!_filtered[index].isAvailable) {
                          _showLockedDialog();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizScreen(
                                exam: mockQuizExam,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.textPrimary,
          size: 20,
        ),
      ),
      title: Text(
        'الامتحانات',
        style: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'محتوى مدفوع 🔒',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'هذا الامتحان يتطلب تفعيل الكود للوصول إليه.',
          style: GoogleFonts.cairo(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Tags / Labels List Screen
// ─────────────────────────────────────────
class TagsListScreen extends StatelessWidget {
  final String subjectName;

  const TagsListScreen({
    super.key,
    this.subjectName = 'الكيمياء',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context),
      body: mockTags.isEmpty
          ? const _EmptyState(message: 'لا توجد وسوم بعد')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: mockTags.length,
              itemBuilder: (context, index) => TagListTile(
                tag: mockTags[index],
                onTap: () {
                  // TODO: Navigate to tag question list
                },
              ),
            ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.textPrimary,
          size: 20,
        ),
      ),
      title: Text(
        'الوسوم',
        style: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Shared: Filter Chip
// ─────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : AppColors.borderLight,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.filter_list_rounded,
                  size: 14, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Shared: Empty State
// ─────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: AppColors.borderLight),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.cairo(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
