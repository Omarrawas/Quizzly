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

class _SubjectExploreScreenState extends State<SubjectExploreScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tagsData = [];
  List<QuizQuestion> _allQuestions = [];
  List<QuizQuestion> _filteredQuestions = [];
  String _searchQuery = '';
  List<String> _viewedTags = [];
  Map<String, Map<String, int>> _tagsStats = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('questions')
          .where('subjectId', isEqualTo: widget.subjectId)
          .get();

      final List<QuizQuestion> questions = snap.docs
          .map((doc) => QuizQuestion.fromFirestore(doc))
          .toList();

      final Map<String, int> tagCounts = {};
      for (var q in questions) {
        if (q.topicNames != null) {
          for (var t in q.topicNames!) {
            final tag = t.trim();
            if (tag.isEmpty) continue;
            tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
          }
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
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
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

  Widget _buildTagsGridSliver(bool isDark) {
    if (_isLoading) {
      return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildTagCard(_tagsData[index], index, isDark),
          childCount: _tagsData.length,
        ),
      ),
    );
  }

  Widget _buildTagCard(Map<String, dynamic> tag, int index, bool isDark) {
    final String name = tag['name'];
    final int count = tag['count'];
    final bool hasViewed = _viewedTags.contains(name);
    final stats = _tagsStats[name];
    final bool hasStats = stats != null && stats['answered']! > 0;
    
    // Protection logic: Only first 3 tags are free
    final bool isLocked = widget.isFree && index >= 3;

    return InkWell(
      onTap: isLocked ? _showLockInfo : () => _openTagQuestions(name),
      child: Opacity(
        opacity: isLocked ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLocked ? Icons.lock_outline_rounded : Icons.local_offer_rounded, 
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1), 
                      size: 24
                    ),
                  ),
                  if (!hasViewed && !isLocked)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : null),
              ),
              const SizedBox(height: 4),
              Text(
                isLocked ? 'محتوى مدفوع' : '$count سؤال',
                style: GoogleFonts.cairo(fontSize: 11, color: isLocked ? Colors.red[300] : (isDark ? const Color(0xFF94A3B8) : Colors.grey)),
              ),
              if (hasStats && !isLocked) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stats['answered']! / count,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                    valueColor: AlwaysStoppedAnimation<Color>(isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1)),
                    minHeight: 3,
                  ),
                ),
              ],
            ],
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
