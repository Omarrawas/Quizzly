import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/subject/presentation/screens/theoretical_lesson_detail_screen.dart';

class TheoreticalLessonListScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String sectionId;
  final String sectionName;
  final bool isAdmin;
  final bool isFree;

  const TheoreticalLessonListScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.sectionId,
    required this.sectionName,
    this.isAdmin = false,
    this.isFree = false,
  });

  @override
  State<TheoreticalLessonListScreen> createState() => _TheoreticalLessonListScreenState();
}

class _TheoreticalLessonListScreenState extends State<TheoreticalLessonListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, String> _chapterNames = {};
  Map<String, int> _chapterOrders = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(DatabaseService.colTopics)
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('sectionId', isEqualTo: widget.sectionId)
          .where('type', isEqualTo: 'chapter')
          .get();

      final Map<String, String> chapters = {};
      final Map<String, int> orders = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        chapters[doc.id] = data['name'] ?? '';
        orders[doc.id] = (data['order'] as num?)?.toInt() ?? 0;
      }

      if (mounted) {
        setState(() {
          _chapterNames = chapters;
          _chapterOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('❌ _loadChapters error: $e\n$stack');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark),
          _buildSearchAndStats(isDark),
          _buildLessonsList(isDark),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
          color: isDark ? Colors.white : AppColors.textPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'دروس ${widget.sectionName}',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [Colors.white, const Color(0xFFF1F5F9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndStats(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'بحث عن درس محدد...',
                  hintStyle: GoogleFonts.cairo(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonsList(bool isDark) {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(DatabaseService.colTopics)
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('sectionId', isEqualTo: widget.sectionId)
          .where('type', isEqualTo: 'lesson')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'حدث خطأ في جلب الدروس. قد يكون السبب نقص في الفهرسة (Index).\nالخطأ: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: SizedBox());
        }

        var docs = snapshot.data!.docs.toList();

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final name = (doc.data() as Map<String, dynamic>)['name']
                    ?.toString()
                    .toLowerCase() ??
                '';
            return name.contains(_searchQuery);
          }).toList();
        }

        // Sort by chapter order primarily, and then lesson order
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aParentId = aData['parentId'] ?? '';
          final bParentId = bData['parentId'] ?? '';

          final aChapterOrder = _chapterOrders[aParentId] ?? 999;
          final bChapterOrder = _chapterOrders[bParentId] ?? 999;

          if (aChapterOrder != bChapterOrder) {
            return aChapterOrder.compareTo(bChapterOrder);
          }

          final aOrder = (aData['order'] is num) ? (aData['order'] as num) : 0;
          final bOrder = (bData['order'] is num) ? (bData['order'] as num) : 0;
          return aOrder.compareTo(bOrder);
        });

        if (docs.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_stories_rounded, size: 64, color: Colors.grey[200]),
                  const SizedBox(height: 16),
                  Text('لا توجد دروس حالياً', style: GoogleFonts.cairo(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final id = doc.id;
                final name = data['name'] ?? '';
                final parentId = data['parentId'];
                final chapterName = _chapterNames[parentId] ?? 'عام';

                // For student view, lock if the user is free and the lesson is not explicitly free
                final bool isLocked =
                    !widget.isAdmin && widget.isFree && data['isFree'] != true;

                return _buildLessonCard(id, name, chapterName, isDark, isLocked, data);
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLessonCard(
    String id,
    String name,
    String chapterName,
    bool isDark,
    bool isLocked,
    Map<String, dynamic> data,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLocked
              ? (isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber.shade200)
              : (isDark ? Colors.white10 : AppColors.borderLight),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: isLocked ? _showPaywall : () => _openLessonInBookMode(id, name, data),
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Opacity(
                opacity: isLocked ? 0.6 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.folder_open_rounded,
                                    size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  chapterName,
                                  style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isLocked)
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey[300],
                        ),
                    ],
                  ),
                ),
              ),
              if (isLocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 24),
                      ),
                    ),
                  ),
                ),
              if (!isLocked && data['isFree'] == true && widget.isFree && !widget.isAdmin)
                Positioned.directional(
                  textDirection: TextDirection.rtl,
                  top: 16,
                  end: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'مجاني',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLessonInBookMode(
    String lessonId,
    String lessonName,
    Map<String, dynamic> data,
  ) async {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TheoreticalLessonDetailScreen(
          lessonId: lessonId,
          lessonName: lessonName,
          subjectId: widget.subjectId,
          subjectName: widget.subjectName,
          sectionId: widget.sectionId,
          data: data,
        ),
      ),
    );
  }

  void _showPaywall() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text(
              'محتوى مقفل',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'هذا الدرس يتطلب الاشتراك في المادة. يرجى تفعيل المادة بالكود لفتح جميع الدروس والاختبارات النظري.',
          style: GoogleFonts.cairo(
            color: isDark ? Colors.white70 : AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to subject hub to activate
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'الاشتراك الآن',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
