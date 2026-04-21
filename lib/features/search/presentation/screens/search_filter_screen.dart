import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/screens/quiz_screen.dart';

// ─────────────────────────────────────────────────────
//  Filter State Model
// ─────────────────────────────────────────────────────
class SearchFilterState {
  final Set<String> selectedTags;
  final Set<String> selectedLists;
  final Set<String> selectedAnswerStatus;
  final String paperType; // 'all' | 'exams' | 'bank'
  final String searchQuery;

  const SearchFilterState({
    this.selectedTags = const {},
    this.selectedLists = const {},
    this.selectedAnswerStatus = const {},
    this.paperType = 'all',
    this.searchQuery = '',
  });

  SearchFilterState copyWith({
    Set<String>? selectedTags,
    Set<String>? selectedLists,
    Set<String>? selectedAnswerStatus,
    String? paperType,
    String? searchQuery,
  }) {
    return SearchFilterState(
      selectedTags: selectedTags ?? this.selectedTags,
      selectedLists: selectedLists ?? this.selectedLists,
      selectedAnswerStatus: selectedAnswerStatus ?? this.selectedAnswerStatus,
      paperType: paperType ?? this.paperType,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      selectedTags.isNotEmpty ||
      selectedLists.isNotEmpty ||
      selectedAnswerStatus.isNotEmpty ||
      paperType != 'all' ||
      searchQuery.isNotEmpty;
}

// ─────────────────────────────────────────────────────
//  Search & Filter Screen
// ─────────────────────────────────────────────────────
class SearchFilterScreen extends StatefulWidget {
  final String subjectName;
  final int totalQuestions;

  const SearchFilterScreen({
    super.key,
    this.subjectName = 'الكيمياء',
    this.totalQuestions = 330,
  });

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final TextEditingController _searchController = TextEditingController();
  SearchFilterState _filters = const SearchFilterState();
  bool _showFilters = true;

  // ── Available filter options ─────────────────────────
  final List<Map<String, String>> _tags = [
    {'id': 'ch4', 'label': 'الفصل الرابع: الربط الكيميائي', 'count': '24'},
    {'id': 'ch1', 'label': 'الفصل الأول: المولات والمعادلات', 'count': '25'},
    {'id': 'ch5', 'label': 'الفصل الخامس: حالات المادة', 'count': '28'},
    {'id': 'ch3', 'label': 'الفصل الثالث: الإلكترونات في الذرات', 'count': '18'},
    {'id': 'ch10', 'label': 'الفصل العاشر: الدورية', 'count': '15'},
    {'id': 'ch7', 'label': 'الفصل السابع: تفاعلات الريدوكس', 'count': '18'},
    {'id': 'ch6', 'label': 'الفصل السادس: تغيرات الانثالبية', 'count': '21'},
  ];

  final List<Map<String, String>> _lists = [
    {'id': 'fav', 'label': 'المفضلة', 'icon': 'heart'},
    {'id': 'important', 'label': 'مهم', 'icon': 'star'},
  ];

  final List<Map<String, String>> _answerStatus = [
    {'id': 'checked', 'label': 'الأسئلة المصححة'},
    {'id': 'wrong', 'label': 'الإجابات الخاطئة'},
    {'id': 'correct', 'label': 'الإجابات الصحيحة'},
  ];

  final List<Map<String, String>> _paperTypes = [
    {'id': 'all', 'label': 'الكل', 'icon': 'all'},
    {'id': 'exams', 'label': 'امتحانات', 'icon': 'exam'},
    {'id': 'bank', 'label': 'بنك الأسئلة', 'icon': 'bank'},
  ];

  // Computed filtered count
  int get _filteredCount =>
      _filters.hasActiveFilters ? (widget.totalQuestions * 0.3).round() : widget.totalQuestions;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleTag(String id) {
    HapticFeedback.selectionClick();
    final updated = Set<String>.from(_filters.selectedTags);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    setState(() => _filters = _filters.copyWith(selectedTags: updated));
  }

  void _toggleList(String id) {
    HapticFeedback.selectionClick();
    final updated = Set<String>.from(_filters.selectedLists);
    if (updated.contains(id)) { updated.remove(id); } else { updated.add(id); }
    setState(() => _filters = _filters.copyWith(selectedLists: updated));
  }

  void _toggleAnswerStatus(String id) {
    HapticFeedback.selectionClick();
    final updated = Set<String>.from(_filters.selectedAnswerStatus);
    if (updated.contains(id)) { updated.remove(id); } else { updated.add(id); }
    setState(() => _filters = _filters.copyWith(selectedAnswerStatus: updated));
  }

  void _setPaperType(String id) {
    HapticFeedback.selectionClick();
    setState(() => _filters = _filters.copyWith(paperType: id));
  }

  void _clearAll() {
    HapticFeedback.mediumImpact();
    _searchController.clear();
    setState(() => _filters = const SearchFilterState());
  }

  void _applySearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(exam: mockQuizExam),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Search bar
          _buildSearchBar(),
          // ── Stats row
          _buildStatsRow(),
          const Divider(height: 1),
          // ── Filters
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: 'الفلاتر', onClear: _filters.hasActiveFilters ? _clearAll : null),
                  const SizedBox(height: 20),

                  // الوسوم
                  _FilterGroup(
                    title: 'الوسوم',
                    child: _buildTagsFilter(),
                  ),
                  const SizedBox(height: 20),

                  // القوائم
                  _FilterGroup(
                    title: 'القوائم',
                    child: _buildCheckboxGroup(_lists, _filters.selectedLists, _toggleList),
                  ),
                  const SizedBox(height: 20),

                  // حالة الإجابة
                  _FilterGroup(
                    title: 'حالة الإجابة',
                    child: _buildCheckboxGroup(
                        _answerStatus, _filters.selectedAnswerStatus, _toggleAnswerStatus),
                  ),
                  const SizedBox(height: 20),

                  // نوع الورقة
                  _FilterGroup(
                    title: 'نوع الورقة',
                    child: _buildPaperTypeGroup(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // ── Bottom action bar
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── AppBar ─────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_forward_ios_rounded,
            color: AppColors.textPrimary, size: 20),
      ),
      title: Text(
        'الأسئلة',
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

  // ── Search Bar ─────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.search_rounded,
                  color: AppColors.textSecondary, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.cairo(fontSize: 14),
                onChanged: (v) =>
                    setState(() => _filters = _filters.copyWith(searchQuery: v)),
                decoration: InputDecoration(
                  hintText: 'ابحث في أسئلة ${widget.subjectName}...',
                  hintStyle: GoogleFonts.cairo(
                      fontSize: 14, color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() =>
                      _filters = _filters.copyWith(searchQuery: ''));
                },
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded,
              size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 5),
          Text(
            '$_filteredCount سؤال',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          const Spacer(),
          // Create filter button
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _filters.hasActiveFilters
                    ? AppColors.primaryBlue.withValues(alpha: 0.1)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _filters.hasActiveFilters
                      ? AppColors.primaryBlue.withValues(alpha: 0.3)
                      : AppColors.borderLight,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: _filters.hasActiveFilters
                        ? AppColors.primaryBlue
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'إنشاء الفلاتر',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _filters.hasActiveFilters
                          ? AppColors.primaryBlue
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (_filters.hasActiveFilters) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_filters.selectedTags.length + _filters.selectedLists.length + _filters.selectedAnswerStatus.length}',
                          style: GoogleFonts.cairo(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tags Filter (horizontal scroll pills) ──────────
  Widget _buildTagsFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags.map((tag) {
        final isSelected = _filters.selectedTags.contains(tag['id']);
        return _TagFilterChip(
          label: '${tag['label']} [${tag['count']}]',
          isSelected: isSelected,
          onTap: () => _toggleTag(tag['id']!),
        );
      }).toList(),
    );
  }

  // ── Checkbox Group ──────────────────────────────────
  Widget _buildCheckboxGroup(
    List<Map<String, String>> items,
    Set<String> selected,
    void Function(String) onToggle,
  ) {
    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: List.generate(
        (items.length / 2).ceil(),
        (rowIndex) {
          final left = rowIndex * 2 < items.length ? items[rowIndex * 2] : null;
          final right = rowIndex * 2 + 1 < items.length ? items[rowIndex * 2 + 1] : null;
          return Row(
            children: [
              if (left != null)
                Expanded(
                  child: _CheckboxTile(
                    label: left['label']!,
                    isChecked: selected.contains(left['id']),
                    onToggle: () => onToggle(left['id']!),
                  ),
                ),
              if (right != null)
                Expanded(
                  child: _CheckboxTile(
                    label: right['label']!,
                    isChecked: selected.contains(right['id']),
                    onToggle: () => onToggle(right['id']!),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          );
        },
      ),
    );
  }

  // ── Paper Type Toggle ───────────────────────────────
  Widget _buildPaperTypeGroup() {
    return Row(
      children: _paperTypes.map((type) {
        final isSelected = _filters.paperType == type['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => _setPaperType(type['id']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                left: type['id'] == _paperTypes.last['id'] ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(12),
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
              child: Column(
                children: [
                  Icon(
                    _getPaperTypeIcon(type['icon']!),
                    size: 18,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    type['label']!,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getPaperTypeIcon(String icon) {
    switch (icon) {
      case 'exam':
        return Icons.assignment_rounded;
      case 'bank':
        return Icons.library_books_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  // ── Bottom Action Bar ───────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 3-dots menu
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.more_horiz_rounded,
                color: AppColors.textSecondary, size: 22),
          ),
          const Spacer(),
          // Search / Apply button
          GestureDetector(
            onTap: _applySearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'بحث ($_filteredCount)',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Section Title with optional clear button
// ─────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onClear;

  const _SectionTitle({required this.title, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (onClear != null)
          GestureDetector(
            onTap: onClear,
            child: Text(
              'مسح الكل',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  Filter Group Container
// ─────────────────────────────────────────
class _FilterGroup extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterGroup({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────
//  Tag Filter Chip (pill style)
// ─────────────────────────────────────────
class _TagFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagFilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF5F3FF)
              : const Color(0xFFFDF4FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C3AED)
                : const Color(0xFFE9D5FF),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF7C3AED)
                : const Color(0xFF9333EA),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Checkbox Tile
// ─────────────────────────────────────────
class _CheckboxTile extends StatelessWidget {
  final String label;
  final bool isChecked;
  final VoidCallback onToggle;

  const _CheckboxTile({
    required this.label,
    required this.isChecked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked ? AppColors.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked
                      ? AppColors.primaryBlue
                      : AppColors.borderLight,
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: isChecked
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      isChecked ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
