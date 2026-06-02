import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_book_mode_screen.dart';

class SubjectExploreScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final bool isFree;

  const SubjectExploreScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.isFree = false,
  });

  @override
  State<SubjectExploreScreen> createState() => _SubjectExploreScreenState();
}

class _SubjectExploreScreenState extends State<SubjectExploreScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasUpdate = false;
  late AnimationController _syncAnimationController;
  List<Map<String, dynamic>> _tagsData = [];
  List<QuizQuestion> _allQuestions = [];
  List<QuizQuestion> _filteredQuestions = [];
  String _searchQuery = '';
  List<String> _viewedTags = [];
  Map<String, Map<String, int>> _tagsStats = {};

  @override
  void initState() {
    super.initState();
    _syncAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fetchData();
  }

  @override
  void dispose() {
    _syncAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) setState(() => _isLoading = true);
      
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Fetch Subject doc to check for lastUpdated
      final subjectDoc = await FirebaseFirestore.instance
          .collection('subjects')
          .doc(widget.subjectId)
          .get();
      
      if (subjectDoc.exists) {
        final serverLastUpdate = (subjectDoc.data()?['lastUpdated'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final localLastUpdate = prefs.getInt('subject_sync_${widget.subjectId}') ?? 0;

        if (localLastUpdate == 0) {
          // First time opening this subject — record current time as baseline
          await prefs.setInt('subject_sync_${widget.subjectId}', DateTime.now().millisecondsSinceEpoch);
        } else if (serverLastUpdate > localLastUpdate) {
          if (mounted) setState(() => _hasUpdate = true);
          _syncAnimationController.repeat(reverse: true);
        } else {
          if (mounted) setState(() => _hasUpdate = false);
          _syncAnimationController.stop();
        }

        if (forceRefresh) {
          await prefs.setInt('subject_sync_${widget.subjectId}', DateTime.now().millisecondsSinceEpoch);
          if (mounted) setState(() => _hasUpdate = false);
          _syncAnimationController.stop();
        }
      }

      final snap = await FirebaseFirestore.instance
          .collection('questions')
          .where('subjectId', isEqualTo: widget.subjectId)
          .get(forceRefresh ? const GetOptions(source: Source.server) : null);

      final List<QuizQuestion> questions = [];
      for (var doc in snap.docs) {
        try {
          questions.add(QuizQuestion.fromFirestore(doc));
        } catch (e) {
          debugPrint('Error parsing question ${doc.id}: $e');
        }
      }

      final Map<String, int> tagCounts = {};
      for (var q in questions) {
        final List<String> tags = [];
        if (q.topicNames != null) tags.addAll(q.topicNames!);
        if (q.tagLabel != null && q.tagLabel!.isNotEmpty) tags.add(q.tagLabel!);

        for (var t in tags) {
          final tag = t.trim();
          if (tag.isEmpty) continue;
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      final List<Map<String, dynamic>> tagsList = tagCounts.keys.map((tag) {
        return {
          'name': tag,
          'count': tagCounts[tag]!,
        };
      }).toList();

      tagsList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _tagsData = tagsList;
          _allQuestions = questions;
          _filteredQuestions = questions;
          _isLoading = false;
        });
        _loadLocalStats();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLocalStats() async {
    final prefs = await SharedPreferences.getInstance();
    final viewedList = prefs.getStringList('viewed_tags_${widget.subjectId}') ?? [];
    
    final Map<String, Map<String, int>> newStats = {};
    for (var tag in _tagsData) {
      final name = tag['name'];
      final data = prefs.getString('quiz_state_$name');
      if (data != null) {
        try {
          final state = json.decode(data);
          // Simple parsing for demo purposes
          newStats[name] = {'answered': (state['checkedQuestions'] as List).length};
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _viewedTags = viewedList;
        _tagsStats = newStats;
      });
    }
  }

  void _onSearch(String query) {
    if (widget.isFree) return; // Disable search for free users
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredQuestions = _allQuestions;
      } else {
        _filteredQuestions = _allQuestions
            .where((q) => q.text.contains(query) || (q.tagLabel?.contains(query) ?? false))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          if (!widget.isFree) _buildSearchBarSliver(isDark),
          if (widget.isFree) 
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : Colors.amber[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF92400E) : Colors.amber[100]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'أنت تتصفح العينة المجانية للمادة. اشترك لفتح كل المواضيع والبحث.',
                        style: GoogleFonts.cairo(fontSize: 12, color: isDark ? Colors.amber[300] : Colors.amber[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_searchQuery.isNotEmpty) 
            _buildSearchResultsSliver()
          else ...[
            _buildSectionTitle(isDark),
            _buildTagsGridSliver(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'استكشاف المحتوى',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: AnimatedBuilder(
            animation: _syncAnimationController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    onPressed: () => _fetchData(forceRefresh: true),
                    icon: Icon(
                      Icons.sync_rounded,
                      color: _hasUpdate
                          ? Colors.orangeAccent.withValues(
                              alpha: 0.4 + (0.6 * _syncAnimationController.value))
                          : Colors.white54,
                    ),
                    tooltip: _hasUpdate ? 'يوجد تحديث جديد! اضغط للتحديث' : 'تحديث البيانات',
                  ),
                  if (_hasUpdate)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orangeAccent.withValues(alpha: 0.6),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBarSliver(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark ? Border.all(color: Colors.white10) : null,
            boxShadow: isDark ? [] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            onChanged: _onSearch,
            style: GoogleFonts.cairo(color: isDark ? Colors.white : null),
            decoration: InputDecoration(
              hintText: 'ابحث عن سؤال، موضوع، أو وسم...',
              hintStyle: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Text(
          'استكشف عبر الوسوم',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  List<_ExploreChapterGroup> _groupTags(List<Map<String, dynamic>> tags) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final List<Map<String, dynamic>> generalTags = [];

    for (var tag in tags) {
      final String name = tag['name'] as String;
      final parts = name.split(' - ');
      if (parts.length >= 2) {
        final chapterName = parts[0].trim();
        if (!grouped.containsKey(chapterName)) {
          grouped[chapterName] = [];
        }
        grouped[chapterName]!.add(tag);
      } else {
        generalTags.add(tag);
      }
    }

    final List<_ExploreChapterGroup> list = [];
    grouped.forEach((chapterName, chapterTags) {
      list.add(_ExploreChapterGroup(name: chapterName, tags: chapterTags));
    });

    if (generalTags.isNotEmpty) {
      list.add(_ExploreChapterGroup(name: 'مواضيع عامة', tags: generalTags));
    }

    return list;
  }

  Widget _buildTagsGridSliver(bool isDark) {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final chapters = _groupTags(_tagsData);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, chapIndex) {
            final chapter = chapters[chapIndex];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chapter Header
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10, right: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bookmark_rounded, 
                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        chapter.name,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Divider(
                          color: isDark ? Colors.white10 : Colors.grey[200],
                          thickness: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Lessons vertical list under this chapter
                Column(
                  children: List.generate(chapter.tags.length, (lessonIndex) {
                    final tag = chapter.tags[lessonIndex];
                    // Find global index in _tagsData to apply lock condition
                    final globalIndex = _tagsData.indexWhere((t) => t['name'] == tag['name']);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildLessonCard(tag, globalIndex, isDark),
                    );
                  }),
                ),
              ],
            );
          },
          childCount: chapters.length,
        ),
      ),
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> tag, int index, bool isDark) {
    final String name = tag['name'];
    final int count = tag['count'];
    final bool hasViewed = _viewedTags.contains(name);
    final stats = _tagsStats[name];
    final bool hasStats = stats != null && stats['answered']! > 0;
    
    // Protection logic: Only first 3 tags are free
    final bool isLocked = widget.isFree && index >= 3;

    // Split "Chapter - Lesson"
    final parts = name.split(' - ');
    final String lessonTitle = parts.length >= 2 ? parts.sublist(1).join(' - ') : name;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLocked ? _showLockInfo : () => _openTagQuestions(name),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Tag / Lock Icon
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D3748) : const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isLocked ? Icons.lock_outline_rounded : Icons.local_offer_rounded, 
                        color: isLocked 
                            ? (isDark ? Colors.red[300] : Colors.red[600])
                            : (isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1)), 
                        size: 20
                      ),
                    ),
                    if (!hasViewed && !isLocked)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                
                // Lesson Title & Question Count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lessonTitle,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 12,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isLocked ? 'محتوى مدفوع' : '$count سؤال',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: isLocked 
                                  ? (isDark ? Colors.red[300] : Colors.red[600]) 
                                  : (isDark ? const Color(0xFF94A3B8) : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      if (hasStats && !isLocked) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: stats['answered']! / count,
                                  backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                                  ),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${((stats['answered']! / count) * 100).toInt()}%',
                              style: GoogleFonts.cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Arrow Icon
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLockInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('هذا الموضوع مخصص للمشتركين. اشترك الآن لفتحه!', style: GoogleFonts.cairo()),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSearchResultsSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: () => _openBookMode(_filteredQuestions, 'نتائج البحث'),
              icon: const Icon(Icons.menu_book_rounded),
              label: Text('فتح في وضع الكتاب (${_filteredQuestions.length} سؤال)', style: GoogleFonts.cairo()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _openTagQuestions(String tagName) async {
    final questions = _allQuestions.where((q) => q.topicNames?.contains(tagName) ?? false).toList();
    if (questions.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> viewed = prefs.getStringList('viewed_tags_${widget.subjectId}') ?? [];
    if (!viewed.contains(tagName)) {
      viewed.add(tagName);
      await prefs.setStringList('viewed_tags_${widget.subjectId}', viewed);
      setState(() => _viewedTags = viewed);
    }

    _openBookMode(questions, tagName);
    _loadLocalStats(); // Refresh stats when returning
  }

  void _openBookMode(List<QuizQuestion> questions, String title) {
    if (questions.isEmpty) return;

    final config = ExamConfig(
      id: 'explore_${widget.subjectId}_${title.hashCode}',
      title: title,
      type: ExamType.bank,
      durationSeconds: 0,
      totalQuestions: questions.length,
      passingScore: 50,
      subjectId: widget.subjectId,
      sectionId: 'explore',
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
  }
}

class _ExploreChapterGroup {
  final String name;
  final List<Map<String, dynamic>> tags;

  const _ExploreChapterGroup({required this.name, required this.tags});
}
