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

  const SubjectExploreScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildSearchBarSliver(),
          if (_searchQuery.isNotEmpty) 
            _buildSearchResultsSliver()
          else ...[
            _buildSectionTitle('استكشف عبر الوسوم'),
            _buildTagsGridSliver(),
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

  Widget _buildSearchBarSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'ابحث عن سؤال، موضوع، أو وسم...',
              hintStyle: GoogleFonts.cairo(fontSize: 14, color: Colors.grey),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildTagsGridSliver() {
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
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildTagCard(_tagsData[index]),
          childCount: _tagsData.length,
        ),
      ),
    );
  }

  Widget _buildTagCard(Map<String, dynamic> tag) {
    final String name = tag['name'];
    final int count = tag['count'];
    final bool hasViewed = _viewedTags.contains(name);
    final stats = _tagsStats[name];
    final bool hasStats = stats != null && stats['answered']! > 0;

    return InkWell(
      onTap: () => _openTagQuestions(name),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_offer_rounded, color: Color(0xFF6366F1), size: 24),
                ),
                if (!hasViewed)
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
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '$count سؤال',
              style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
            ),
            if (hasStats) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: stats['answered']! / count,
                  backgroundColor: Colors.grey[100],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
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
