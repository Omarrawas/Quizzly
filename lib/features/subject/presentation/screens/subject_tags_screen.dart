import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/screens/exam_book_mode_screen.dart';

class SubjectTagsScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const SubjectTagsScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SubjectTagsScreen> createState() => _SubjectTagsScreenState();
}

class _SubjectTagsScreenState extends State<SubjectTagsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tagsData = [];
  List<QuizQuestion> _allQuestions = [];

  List<String> _viewedTags = [];
  String? _lastViewedTag;
  Map<String, Map<String, int>> _tagsStats = {};

  @override
  void initState() {
    super.initState();
    _fetchTags();
  }

  Future<void> _loadLocalStats() async {
    final prefs = await SharedPreferences.getInstance();
    
    final viewedList = prefs.getStringList('viewed_tags_${widget.subjectId}') ?? [];
    final lastViewed = prefs.getString('last_viewed_tag_${widget.subjectId}');
    
    final Map<String, Map<String, int>> newStats = {};
    
    for (var tag in _tagsData) {
      final name = tag['name'];
      final data = prefs.getString('quiz_state_$name');
      if (data != null) {
        try {
          final state = json.decode(data) as Map<String, dynamic>;
          int correct = 0;
          int wrong = 0;
          int answered = 0;
          if (state['answerStates'] != null) {
             final states = state['answerStates'] as Map<String, dynamic>;
             states.forEach((k, v) {
               final stateVal = v as String;
               if (stateVal == 'correct') {
                 correct++;
               } else if (stateVal == 'wrong') {
                 wrong++;
               }
             });
          }
          if (state['checkedQuestions'] != null) {
            answered = (state['checkedQuestions'] as List).length;
          }
          newStats[name] = {
            'correct': correct,
            'wrong': wrong,
            'answered': answered,
          };
        } catch (e) {
          // Ignore parse errors for individual tags
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _viewedTags = viewedList;
        _lastViewedTag = lastViewed;
        _tagsStats = newStats;
      });
    }
  }

  Future<void> _fetchTags() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('questions')
          .where('subjectId', isEqualTo: widget.subjectId)
          .get();

      final List<QuizQuestion> questions = snap.docs
          .map((doc) => QuizQuestion.fromFirestore(doc))
          .toList();

      final Map<String, int> tagCounts = {};
      final Map<String, DateTime> tagLatestDate = {};

      for (var doc in snap.docs) {
        final data = doc.data();
        final List<dynamic>? topics = data['topicNames'];
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        if (topics != null && topics.isNotEmpty) {
          for (var t in topics) {
            final tag = t.toString().trim();
            if (tag.isEmpty) continue;
            tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
            
            if (!tagLatestDate.containsKey(tag) || createdAt.isAfter(tagLatestDate[tag]!)) {
              tagLatestDate[tag] = createdAt;
            }
          }
        }
      }

      final now = DateTime.now();
      final List<Map<String, dynamic>> tagsList = tagCounts.keys.map((tag) {
        final isNew = now.difference(tagLatestDate[tag] ?? now).inDays <= 7;
        return {
          'name': tag,
          'count': tagCounts[tag]!,
          'isNew': isNew,
        };
      }).toList();

      tagsList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _tagsData = tagsList;
          _allQuestions = questions;
          _isLoading = false;
        });
        _loadLocalStats();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل الوسوم: $e')),
        );
      }
    }
  }

  void _onTagTapped(Map<String, dynamic> tagData) async {
    final tagName = tagData['name'] as String;
    final tagQuestions = _allQuestions.where((q) => q.topicNames?.contains(tagName) ?? false).toList();

    if (tagQuestions.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> viewed = prefs.getStringList('viewed_tags_${widget.subjectId}') ?? [];
    if (!viewed.contains(tagName)) {
      viewed.add(tagName);
      await prefs.setStringList('viewed_tags_${widget.subjectId}', viewed);
    }
    await prefs.setString('last_viewed_tag_${widget.subjectId}', tagName);
    
    setState(() {
      if (!_viewedTags.contains(tagName)) _viewedTags.add(tagName);
      _lastViewedTag = tagName;
    });

    final config = ExamConfig(
      id: '${widget.subjectId}_tag_$tagName',
      title: tagName,
      type: ExamType.bank,
      durationSeconds: 0,
      totalQuestions: tagQuestions.length,
      passingScore: 50,
      subjectId: widget.subjectId,
      sectionId: '',
      category: 'التصنيفات',
      staticQuestionIds: tagQuestions.map((q) => q.id ?? '').toList(),
      isFree: true,
      lastUpdated: DateTime.now(),
      createdAt: DateTime.now(),
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamBookModeScreen(
          config: config,
          questions: tagQuestions,
          isSubExam: true,
        ),
      ),
    );
    
    // Refresh stats when coming back
    _loadLocalStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الوسوم',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tagsData.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد وسوم متاحة',
                    style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: _tagsData.length,
                  itemBuilder: (context, index) {
                    final tag = _tagsData[index];
                    return _buildTagCard(tag);
                  },
                ),
    );
  }

  Widget _buildTagCard(Map<String, dynamic> tag) {
    final String name = tag['name'];
    final int count = tag['count'];
    final bool isOriginallyNew = tag['isNew'];
    
    final bool hasViewed = _viewedTags.contains(name);
    final bool isLastViewed = _lastViewedTag == name;
    
    // If it has been viewed, it's no longer "New" to the user
    final bool isNew = isOriginallyNew && !hasViewed;
    
    final stats = _tagsStats[name];
    final bool hasStats = stats != null && stats['answered']! > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _onTagTapped(tag),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Right side: Icon in a purple circle
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6366F1), // Indigo/Purple
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.local_offer_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Middle: Text & Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE), // Light blue background
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$count',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0369A1), // Dark blue text
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.description_rounded, size: 14, color: Color(0xFF0369A1)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Left side: "New" or "Recently Viewed" indicator
                    if (isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED), // Light orange
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'جديد',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEA580C), // Orange
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEA580C),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isLastViewed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'شوهد مؤخراً',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.history_rounded, size: 14, color: Colors.grey.shade500),
                          ],
                        ),
                      )
                  ],
                ),
                
                // Bottom: Progress bar if there's saved stats
                if (hasStats) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.analytics_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'تقدمك في هذا الوسم',
                        style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              if (stats['correct']! > 0)
                                Expanded(
                                  flex: stats['correct']!,
                                  child: Container(height: 6, color: const Color(0xFF10B981)),
                                ),
                              if (stats['wrong']! > 0)
                                Expanded(
                                  flex: stats['wrong']!,
                                  child: Container(height: 6, color: const Color(0xFFEF4444)),
                                ),
                              if (count - stats['answered']! > 0)
                                Expanded(
                                  flex: count - stats['answered']!,
                                  child: Container(height: 6, color: Colors.grey[200]),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${stats['answered']}/$count',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

