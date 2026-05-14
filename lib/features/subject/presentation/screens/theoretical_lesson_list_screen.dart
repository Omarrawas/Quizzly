import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_book_mode_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/theoretical_section_management_screen.dart';

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
      for (var doc in snap.docs) {
        chapters[doc.id] = (doc.data() as Map<String, dynamic>)['name'] ?? '';
      }
      
      if (mounted) {
        setState(() {
          _chapterNames = chapters;
          _isLoading = false;
        });
      }
    } catch (e) {
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
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
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
                boxShadow: isDark ? [] : [
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
    if (_isLoading) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(DatabaseService.colTopics)
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('sectionId', isEqualTo: widget.sectionId)
          .where('type', isEqualTo: 'lesson')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SliverToBoxAdapter(child: SizedBox());
        
        var docs = snapshot.data!.docs;
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final name = (doc.data() as Map<String, dynamic>)['name']?.toString().toLowerCase() ?? '';
            return name.contains(_searchQuery);
          }).toList();
        }

        // Sort by chapter order and then lesson order
        // For simplicity here, we'll sort by name if order is missing
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aOrder = aData['order'] ?? 0;
          final bOrder = bData['order'] ?? 0;
          return (aOrder as num).compareTo(bOrder as num);
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
                
                // For student view, limit access to first 3 lessons if free
                final bool isLocked = !widget.isAdmin && widget.isFree && index >= 3;

                return _buildLessonCard(id, name, chapterName, isDark, isLocked);
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLessonCard(String id, String name, String chapterName, bool isDark, bool isLocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
        boxShadow: isDark ? [] : [
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
          onTap: isLocked ? _showPaywall : () => _onLessonTap(id, name),
          borderRadius: BorderRadius.circular(24),
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
                  child: Icon(
                    isLocked ? Icons.lock_rounded : Icons.menu_book_rounded, 
                    color: isLocked ? Colors.amber : AppColors.primaryBlue
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
                          Icon(Icons.folder_open_rounded, size: 12, color: Colors.grey[400]),
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
                Icon(
                  Icons.arrow_forward_ios_rounded, 
                  size: 14, 
                  color: Colors.grey[300]
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onLessonTap(String lessonId, String lessonName) async {
    if (widget.isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheoreticalSectionManagementScreen(
            sectionId: widget.sectionId,
            sectionName: widget.sectionName,
            subjectId: widget.subjectId,
            breadcrumbs: [widget.subjectName, widget.sectionName, lessonName],
            lessonId: lessonId,
            lessonName: lessonName,
          ),
        ),
      );
    } else {
      // Student view: Open in Book Mode
      _openLessonInBookMode(lessonId, lessonName);
    }
  }

  Future<void> _openLessonInBookMode(String lessonId, String lessonName) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection(DatabaseService.colQuestions)
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('topicIds', arrayContains: lessonId)
          .get();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loader

      final questions = snap.docs.map((doc) => QuizQuestion.fromFirestore(doc)).toList();
      
      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا توجد أسئلة في هذا الدرس حالياً', style: GoogleFonts.cairo()))
        );
        return;
      }

      final config = ExamConfig(
        id: 'lesson_$lessonId',
        title: lessonName,
        type: ExamType.bank,
        durationSeconds: 0,
        totalQuestions: questions.length,
        passingScore: 50,
        subjectId: widget.subjectId,
        sectionId: widget.sectionId,
        staticQuestionIds: questions.map((q) => q.id ?? '').toList(),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExamBookModeScreen(
            config: config,
            questions: questions,
            isSubExam: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _showPaywall() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('اشترك لفتح جميع الدروس ومميزات التطبيق الكاملة!', style: GoogleFonts.cairo()),
        backgroundColor: AppColors.primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
