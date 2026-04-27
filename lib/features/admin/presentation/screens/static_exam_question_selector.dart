import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';

class StaticExamQuestionSelector extends StatefulWidget {
  final String examId;
  final String examTitle;
  final String subjectId;
  final String sectionId;
  final List<String> initialSelectedIds;

  const StaticExamQuestionSelector({
    super.key,
    required this.examId,
    required this.examTitle,
    required this.subjectId,
    required this.sectionId,
    required this.initialSelectedIds,
  });

  @override
  State<StaticExamQuestionSelector> createState() => _StaticExamQuestionSelectorState();
}

class _StaticExamQuestionSelectorState extends State<StaticExamQuestionSelector> {
  late List<String> _selectedIds;
  String _searchQuery = '';

  // Topic filter: null = show all
  String? _selectedTopicId;

  // Topic hierarchy: chapters → lessons
  List<Map<String, dynamic>> _chapters = [];
  Map<String, List<Map<String, dynamic>>> _lessonsByChapter = {};
  bool _isLoadingTopics = true;

  // Collapsed chapters
  final Set<String> _collapsedChapters = {};

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelectedIds);
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(DatabaseService.colTopics)
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('sectionId', isEqualTo: widget.sectionId)
          .get();

      final chapters = <Map<String, dynamic>>[];
      final lessonsByChapter = <String, List<Map<String, dynamic>>>{};

      for (var doc in snap.docs) {
        final data = doc.data();
        final type = data['type'] ?? '';
        final entry = {...data, 'id': doc.id};

        if (type == 'chapter') {
          chapters.add(entry);
        } else if (type == 'lesson') {
          final parentId = data['parentId'] as String?;
          if (parentId != null) {
            lessonsByChapter.putIfAbsent(parentId, () => []).add(entry);
          }
        }
      }

      // Sort by order field
      chapters.sort((a, b) => ((a['order'] ?? 0) as num).compareTo((b['order'] ?? 0) as num));
      for (var list in lessonsByChapter.values) {
        list.sort((a, b) => ((a['order'] ?? 0) as num).compareTo((b['order'] ?? 0) as num));
      }

      if (mounted) {
        setState(() {
          _chapters = chapters;
          _lessonsByChapter = lessonsByChapter;
          _isLoadingTopics = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTopics = false);
    }
  }

  Future<void> _saveSelection() async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Get Exam Details
      final examSnap = await FirebaseFirestore.instance
          .collection(DatabaseService.colExams)
          .doc(widget.examId)
          .get();
      final examData = examSnap.data() ?? {};
      final tagName = examData['category'] ?? widget.examTitle;

      // 2. Update Exam
      batch.update(
        FirebaseFirestore.instance.collection(DatabaseService.colExams).doc(widget.examId),
        {
          'staticQuestions': _selectedIds,
          'totalQuestions': _selectedIds.length,
          'duration': _selectedIds.length * 60,
        },
      );

      // 3. Handle Tags
      final allAffectedIds = {..._selectedIds, ...widget.initialSelectedIds};

      for (var id in allAffectedIds) {
        final qSnap = await FirebaseFirestore.instance
            .collection(DatabaseService.colQuestions)
            .doc(id)
            .get();
        final qData = qSnap.data() ?? {};
        List<String> currentTags = List<String>.from(qData['examTags'] ?? []);

        if (_selectedIds.contains(id)) {
          if (!currentTags.contains(tagName)) currentTags.add(tagName);
        } else {
          currentTags.remove(tagName);
        }

        batch.update(
          FirebaseFirestore.instance.collection(DatabaseService.colQuestions).doc(id),
          {'examTags': currentTags, 'isRepeated': currentTags.length > 1},
        );
      }

      await batch.commit();
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('تم تحديث أسئلة الاختبار والأوسمة بنجاح')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('خطأ أثناء الحفظ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تحديد أسئلة الاختبار',
                style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.examTitle, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saveSelection,
            child: Text(
              'حفظ (${_selectedIds.length})',
              style: GoogleFonts.cairo(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark),
          _buildTopicClassifier(isDark),
          Expanded(child: _buildQuestionsList(isDark)),
        ],
      ),
    );
  }

  // ── Search Bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'بحث في نص السؤال...',
          hintStyle: GoogleFonts.cairo(fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          fillColor: isDark ? Colors.black26 : Colors.white,
          filled: true,
        ),
      ),
    );
  }

  // ── Topic Classifier ────────────────────────────────────────────────────────
  Widget _buildTopicClassifier(bool isDark) {
    if (_isLoadingTopics) {
      return const LinearProgressIndicator();
    }

    if (_chapters.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.topic_rounded, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  _selectedTopicId == null
                      ? 'جميع المواضيع'
                      : 'تصفية: ${_getTopicName(_selectedTopicId!)}',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _selectedTopicId == null ? AppColors.textSecondary : AppColors.primaryBlue,
                  ),
                ),
                const Spacer(),
                if (_selectedTopicId != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedTopicId = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('إلغاء التصفية',
                          style: GoogleFonts.cairo(fontSize: 11, color: Colors.red)),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Chapters & Lessons list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: _chapters.map((chapter) {
                final chapterId = chapter['id'] as String;
                final chapterName = chapter['name'] as String? ?? '';
                final lessons = _lessonsByChapter[chapterId] ?? [];
                final isCollapsed = _collapsedChapters.contains(chapterId);
                final isChapterSelected = _selectedTopicId == chapterId;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chapter row
                    InkWell(
                      onTap: () => setState(() {
                        _selectedTopicId = isChapterSelected ? null : chapterId;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            // Collapse toggle
                            if (lessons.isNotEmpty)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() {
                                  if (isCollapsed) {
                                    _collapsedChapters.remove(chapterId);
                                  } else {
                                    _collapsedChapters.add(chapterId);
                                  }
                                }),
                                child: Icon(
                                  isCollapsed
                                      ? Icons.chevron_left_rounded
                                      : Icons.expand_more_rounded,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              )
                            else
                              const SizedBox(width: 20),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('فصل',
                                  style: GoogleFonts.cairo(
                                      fontSize: 9, color: AppColors.primaryBlue)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                chapterName,
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isChapterSelected
                                      ? AppColors.primaryBlue
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isChapterSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primaryBlue, size: 16),
                          ],
                        ),
                      ),
                    ),
                    // Lessons
                    if (!isCollapsed && lessons.isNotEmpty)
                      ...lessons.map((lesson) {
                        final lessonId = lesson['id'] as String;
                        final lessonName = lesson['name'] as String? ?? '';
                        final isLessonSelected = _selectedTopicId == lessonId;

                        return InkWell(
                          onTap: () => setState(() {
                            _selectedTopicId = isLessonSelected ? null : lessonId;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 36, left: 12, top: 6, bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_forward_ios_rounded,
                                    size: 10, color: Colors.grey[400]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lessonName,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: isLessonSelected ? AppColors.primaryBlue : null,
                                      fontWeight: isLessonSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isLessonSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppColors.primaryBlue, size: 14),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getTopicName(String id) {
    for (var c in _chapters) {
      if (c['id'] == id) return c['name'] ?? '';
    }
    for (var lessons in _lessonsByChapter.values) {
      for (var l in lessons) {
        if (l['id'] == id) return l['name'] ?? '';
      }
    }
    return '';
  }

  /// Returns "Chapter - Lesson" label for a question's topicIds list
  String _getTopicLabel(List<dynamic>? topicIds) {
    if (topicIds == null || topicIds.isEmpty) return '';
    final lessonId = topicIds.first.toString();

    // Find in lessons
    for (var entry in _lessonsByChapter.entries) {
      final chapterId = entry.key;
      for (var lesson in entry.value) {
        if (lesson['id'] == lessonId) {
          final chapterName = _getTopicName(chapterId);
          final lessonName = lesson['name'] ?? '';
          return '$chapterName - $lessonName';
        }
      }
    }

    // Fallback: maybe it's a chapter id directly
    final chapterName = _getTopicName(lessonId);
    return chapterName;
  }

  String _translateDifficulty(String? d) {
    switch (d) {
      case 'easy': return 'سهل';
      case 'hard': return 'صعب';
      default: return 'متوسط';
    }
  }

  // ── Questions List ──────────────────────────────────────────────────────────
  Widget _buildQuestionsList(bool isDark) {
    Query query = FirebaseFirestore.instance
        .collection(DatabaseService.colQuestions)
        .where('subjectId', isEqualTo: widget.subjectId)
        .where('parentId', isEqualTo: widget.sectionId);

    if (_selectedTopicId != null) {
      query = query.where('topicIds', arrayContains: _selectedTopicId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }

        var docs = snapshot.data?.docs ?? [];

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final text =
                (doc.data() as Map<String, dynamic>)['text']?.toString().toLowerCase() ?? '';
            return text.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Text('لا توجد أسئلة تطابق البحث', style: GoogleFonts.cairo()),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final id = doc.id;
            final isSelected = _selectedIds.contains(id);

            final typeStr = data['type'] == 'mcq' ? 'اختيار' : (data['type'] == 'tf' ? 'صح/خطأ' : 'مقالي');
            final typeColor = data['type'] == 'mcq' ? Colors.blue : (data['type'] == 'tf' ? Colors.teal : Colors.orange);
            final topicLabel = _getTopicLabel(data['topicIds'] as List?);
            final diffLabel = _translateDifficulty(data['difficulty']);
            final examTags = (data['examTags'] as List?) ?? [];
            final isRepeated = examTags.length > 1;

            return GestureDetector(
              onTap: () => setState(() {
                if (_selectedIds.contains(id)) {
                  _selectedIds.remove(id);
                } else {
                  _selectedIds.add(id);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryBlue.withValues(alpha: 0.04)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white12 : AppColors.borderLight),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checkbox
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryBlue : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type badge + question text
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    typeStr,
                                    style: GoogleFonts.cairo(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: typeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['text'] ?? '',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? AppColors.primaryBlue : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Topic label
                            if (topicLabel.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_tree_rounded,
                                        size: 11, color: AppColors.primaryBlue),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        topicLabel,
                                        style: GoogleFonts.cairo(
                                          fontSize: 10,
                                          color: AppColors.primaryBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Chips row: difficulty + exam tags
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // Difficulty
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    diffLabel,
                                    style: GoogleFonts.cairo(
                                        fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                                // Repeated badge
                                if (isRepeated)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.repeat_rounded, size: 9, color: Colors.red),
                                        const SizedBox(width: 3),
                                        Text('مكرر',
                                            style: GoogleFonts.cairo(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red[800])),
                                      ],
                                    ),
                                  ),
                                // Exam tags
                                ...examTags.map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bookmark_rounded, size: 9, color: Colors.orange),
                                      const SizedBox(width: 3),
                                      Text(
                                        tag.toString(),
                                        style: GoogleFonts.cairo(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange[800]),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
