import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/admin/presentation/screens/bulk_upload_screen.dart';
import 'package:quizzly/features/admin/domain/services/bulk_upload_service.dart';
import 'package:quizzly/features/admin/presentation/screens/question_management_screen.dart';


class TheoreticalSectionManagementScreen extends StatefulWidget {
  final String? sectionId;
  final String? sectionName;
  final String subjectId;
  final List<String> breadcrumbs;
  final String? lessonId;
  final String? lessonName;

  const TheoreticalSectionManagementScreen({
    super.key,
    this.sectionId,
    this.sectionName,
    required this.subjectId,
    required this.breadcrumbs,
    this.lessonId,
    this.lessonName,
  });

  @override
  State<TheoreticalSectionManagementScreen> createState() => _TheoreticalSectionManagementScreenState();
}

class _TheoreticalSectionManagementScreenState extends State<TheoreticalSectionManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, Map<String, dynamic>> _topicsMap = {};
  bool _isLoadingTopics = true;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedChapterId;
  String? _selectedLessonId;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(DatabaseService.colTopics)
          .where('subjectId', isEqualTo: widget.subjectId)
          .get();
      
      final Map<String, Map<String, dynamic>> topics = {};
      for (var doc in snap.docs) {
        topics[doc.id] = doc.data();
      }
      
      if (mounted) {
        setState(() {
          _topicsMap = topics;
          _isLoadingTopics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTopics = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getTopicLabel(List<dynamic>? topicIds) {
    if (topicIds == null || topicIds.isEmpty) return 'بدون موضوع';
    
    final topicId = topicIds.first.toString();
    final topicData = _topicsMap[topicId];
    if (topicData == null) return 'موضوع غير معروف';
    
    final name = topicData['name'] ?? '';
    final parentId = topicData['parentId'];
    
    if (parentId != null) {
      final parentData = _topicsMap[parentId];
      if (parentData != null) {
        return "${parentData['name']} - $name";
      }
    }
    
    return name;
  }

  String _getChapterName(List<dynamic>? topicIds) {
    if (topicIds == null || topicIds.isEmpty) return 'عام';
    
    final topicId = topicIds.first.toString();
    final topicData = _topicsMap[topicId];
    if (topicData == null) return 'عام';
    
    final parentId = topicData['parentId'];
    if (parentId != null) {
      final parentData = _topicsMap[parentId];
      return parentData?['name'] ?? 'عام';
    }
    
    return topicData['name'] ?? 'عام';
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.lessonName != null 
              ? 'أسئلة: ${widget.lessonName}' 
              : (widget.sectionName ?? 'بنك الأسئلة'),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'تصدير الأسئلة',
            onPressed: _showExportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'رفع أسئلة (Excel)',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => BulkUploadScreen(subjectId: widget.subjectId)));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(isDark),
          _buildSearchAndFilter(isDark),
          Expanded(child: _buildQuestionsList(isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddQuestionDialog(context),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('إضافة سؤال', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    // Extract chapters and current lessons
    final chapters = _topicsMap.values
        .where((t) => t['parentId'] == null)
        .toList();
    
    // Sort chapters by order
    chapters.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    final lessons = _selectedChapterId == null 
        ? [] 
        : _topicsMap.values
            .where((t) => t['parentId'] == _selectedChapterId)
            .toList();
    
    // Sort lessons by order
    lessons.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
              boxShadow: isDark ? [] : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: GoogleFonts.cairo(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ابحث عن سؤال...',
                hintStyle: GoogleFonts.cairo(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),
        ),

        // Chapters Filter
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip(
                label: 'الكل',
                isSelected: _selectedChapterId == null,
                onSelected: () => setState(() {
                  _selectedChapterId = null;
                  _selectedLessonId = null;
                }),
                isDark: isDark,
              ),
              ...chapters.map((chapter) {
                final id = _topicsMap.keys.firstWhere((k) => _topicsMap[k] == chapter);
                return _buildFilterChip(
                  label: chapter['name'] ?? '',
                  isSelected: _selectedChapterId == id,
                  onSelected: () => setState(() {
                    _selectedChapterId = id;
                    _selectedLessonId = null;
                  }),
                  isDark: isDark,
                );
              }),
            ],
          ),
        ),

        // Lessons Filter (Only if a chapter is selected)
        if (_selectedChapterId != null && lessons.isNotEmpty)
          Container(
            height: 45,
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(
                  label: 'جميع دروس الفصل',
                  isSelected: _selectedLessonId == null,
                  onSelected: () => setState(() => _selectedLessonId = null),
                  isDark: isDark,
                  isSecondary: true,
                ),
                ...lessons.map((lesson) {
                  final id = _topicsMap.keys.firstWhere((k) => _topicsMap[k] == lesson);
                  return _buildFilterChip(
                    label: lesson['name'] ?? '',
                    isSelected: _selectedLessonId == id,
                    onSelected: () => setState(() => _selectedLessonId = id),
                    isDark: isDark,
                    isSecondary: true,
                  );
                }),
              ],
            ),
          ),
        
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required bool isDark,
    bool isSecondary = false,
  }) {
    final activeColor = isSecondary ? Colors.teal : AppColors.primaryBlue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: isSecondary ? 11 : 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: activeColor,
        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildBreadcrumbs(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: widget.breadcrumbs.asMap().entries.map((entry) {
            return Row(
              children: [
                if (entry.key > 0) Icon(Icons.chevron_left_rounded, size: 16, color: Colors.grey[400]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.value,
                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildQuestionsList(bool isDark) {
    if (_isLoadingTopics) return const Center(child: CircularProgressIndicator());

    Query query = FirebaseFirestore.instance
        .collection(DatabaseService.colQuestions)
        .where('subjectId', isEqualTo: widget.subjectId);

    if (widget.lessonId != null) {
      query = query.where('topicIds', arrayContains: widget.lessonId);
    } else if (widget.sectionId != null) {
      query = query.where('parentId', isEqualTo: widget.sectionId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return _emptyState('حدث خطأ أثناء جلب الأسئلة: ${snapshot.error}', isDark, isError: true);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState('لا توجد أسئلة في هذا القسم حالياً', isDark);
        }

        // Apply Search and Filters
        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Search Filter
          if (_searchQuery.isNotEmpty) {
            final text = (data['text'] ?? '').toString().toLowerCase();
            if (!text.contains(_searchQuery)) return false;
          }

          // Lesson Filter
          if (_selectedLessonId != null) {
            final topicIds = data['topicIds'] as List?;
            if (topicIds == null || !topicIds.contains(_selectedLessonId)) return false;
          } 
          // Chapter Filter (if no specific lesson selected)
          else if (_selectedChapterId != null) {
            final topicIds = data['topicIds'] as List?;
            if (topicIds == null || topicIds.isEmpty) return false;
            
            // Check if any of the topics belong to this chapter
            bool belongsToChapter = false;
            for (var tid in topicIds) {
              if (_topicsMap[tid]?['parentId'] == _selectedChapterId) {
                belongsToChapter = true;
                break;
              }
            }
            if (!belongsToChapter) return false;
          }

          return true;
        }).toList();

        if (docs.isEmpty) {
          return _emptyState('لا توجد نتائج تطابق البحث أو الفلاتر', isDark);
        }

        // Group and sort questions by chapter and lesson order
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
        
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final chapter = _getChapterName(data['topicIds']);
          if (!grouped.containsKey(chapter)) grouped[chapter] = [];
          grouped[chapter]!.add(doc);
        }

        // Sort Chapters by their order in _topicsMap
        final sortedChapters = grouped.keys.toList();
        sortedChapters.sort((a, b) {
          final aTopic = _topicsMap.values.firstWhere((t) => t['name'] == a && t['parentId'] == null, orElse: () => {});
          final bTopic = _topicsMap.values.firstWhere((t) => t['name'] == b && t['parentId'] == null, orElse: () => {});
          return (aTopic['order'] ?? 0).compareTo(bTopic['order'] ?? 0);
        });
        
        final List<Widget> listItems = [];
        
        for (var chapter in sortedChapters) {
          // Sort questions within chapter by lesson order
          final questionsInChapter = grouped[chapter]!;
          questionsInChapter.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTopicId = (aData['topicIds'] as List?)?.firstOrNull;
            final bTopicId = (bData['topicIds'] as List?)?.firstOrNull;
            final aOrder = _topicsMap[aTopicId]?['order'] ?? 0;
            final bOrder = _topicsMap[bTopicId]?['order'] ?? 0;
            return aOrder.compareTo(bOrder);
          });

          // Add Header
          listItems.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    chapter,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${questionsInChapter.length} سؤال',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          // Add Questions
          for (var doc in questionsInChapter) {
            final data = doc.data() as Map<String, dynamic>;
            final id = doc.id;
            listItems.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildQuestionCard(id, data, isDark, key: ValueKey(id)),
              ),
            );
          }
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: listItems,
        );
      },
    );
  }

  Widget _buildQuestionCard(String id, Map<String, dynamic> data, bool isDark, {Key? key}) {
    final String typeStr = data['type'] == 'mcq' ? 'أتمتة' : (data['type'] == 'tf' ? 'صح/خطأ' : 'مقالي');
    final Color typeColor = data['type'] == 'mcq' ? Colors.blue : (data['type'] == 'tf' ? Colors.teal : Colors.orange);
    final questionText = data['text'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: ExpansionTile(
        key: PageStorageKey(id),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(typeStr, style: GoogleFonts.cairo(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    questionText,
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data['topicIds'] != null && (data['topicIds'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _getTopicLabel(data['topicIds']),
                        style: GoogleFonts.cairo(fontSize: 10, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (data['examTags'] != null && (data['examTags'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // 1. "Mukarrar" Tag if applicable
                          if ((data['examTags'] as List).length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.repeat_rounded, size: 10, color: Colors.red),
                                  const SizedBox(width: 4),
                                  Text(
                                    'مكرر',
                                    style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red[800]),
                                  ),
                                ],
                              ),
                            ),
                          // 2. Individual Dora Tags
                          ...(data['examTags'] as List).map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bookmark_rounded, size: 10, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  tag.toString(),
                                  style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 10),
                if (data['options'] != null) ...[
                  Text('الخيارات:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  ...(data['options'] as List).map((opt) {
                    final isCorrect = (data['correctOptionIds'] as List?)?.contains(opt['id']) ?? (opt['id'] == data['correctOptionId']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green.withValues(alpha: 0.05) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, 
                               size: 16, color: isCorrect ? Colors.green : Colors.grey),
                          const SizedBox(width: 10),
                          Expanded(child: Text(opt['text'] ?? '', style: GoogleFonts.cairo(fontSize: 12))),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    _buildMetaChip(Icons.bar_chart_rounded, _translateDifficulty(data['difficulty']), Colors.blue),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: Text('تعديل', style: GoogleFonts.cairo()),
                      onPressed: () => _showEditQuestionDialog(id, data),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                      label: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
                      onPressed: () => _confirmDelete(id, questionText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _translateDifficulty(String? d) {
    switch (d) {
      case 'easy': return 'سهل';
      case 'hard': return 'صعب';
      case 'medium':
      default: return 'متوسط';
    }
  }

  Widget _buildMetaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showAddQuestionDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionManagementScreen(
          sectionId: widget.sectionId,
          subjectId: widget.subjectId,
          lessonId: widget.lessonId,
          lessonName: widget.lessonName,
        ),
      ),
    );
  }

  void _showEditQuestionDialog(String id, Map<String, dynamic> currentData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionManagementScreen(
          sectionId: widget.sectionId ?? 'global', // Fallback for global bank
          subjectId: widget.subjectId,
          lessonId: widget.lessonId,
          lessonName: widget.lessonName,
          questionId: id,
          currentData: currentData,
        ),
      ),
    );
  }

  void _confirmDelete(String id, String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('هل أنت متأكد من حذف هذا السؤال؟\n${text.substring(0, text.length > 50 ? 50 : text.length)}...', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              try {
                await _dbService.deleteDoc(DatabaseService.colQuestions, id);
                if (mounted) {
                  navigator.pop();
                  _showStatusSnackBar('تم حذف السؤال بنجاح', isError: false);
                }
              } catch (e) {
                if (mounted) _showStatusSnackBar('فشل الحذف: $e', isError: true);
              }
            },
            child: Text('حذف', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر صيغة التصدير', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_view_rounded, color: Colors.green),
              title: Text('Excel (.xlsx)', style: GoogleFonts.cairo()),
              onTap: () {
                Navigator.pop(context);
                _exportQuestions(isExcel: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded, color: Colors.blue),
              title: Text('JSON (.json)', style: GoogleFonts.cairo()),
              onTap: () {
                Navigator.pop(context);
                _exportQuestions(isExcel: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportQuestions({required bool isExcel}) async {
    try {
      final questionsSnap = await FirebaseFirestore.instance
          .collection(DatabaseService.colQuestions)
          .where('parentId', isEqualTo: widget.sectionId)
          .get();
      
      final List<QuizQuestion> questions = questionsSnap.docs.map((doc) => QuizQuestion.fromFirestore(doc)).toList();
      
      if (!mounted) return;

      if (questions.isEmpty) {
        _showStatusSnackBar('لا توجد أسئلة لتصديرها', isError: true);
        return;
      }
      
      final bytes = isExcel 
          ? BulkUploadService.generateExcelTemplate(questions: questions, topicsMap: _topicsMap)
          : BulkUploadService.generateJSONTemplate(questions);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'questions_${widget.sectionName ?? "global"}_$timestamp';
      
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: isExcel ? 'xlsx' : 'json',
        mimeType: isExcel ? MimeType.microsoftExcel : MimeType.json,
      );

      if (mounted) {
        _showStatusSnackBar('تم حفظ الملف بنجاح', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showStatusSnackBar('فشل التصدير: $e', isError: true);
      }
    }
  }
  void _showStatusSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }

  Widget _emptyState(String message, bool isDark, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.quiz_outlined,
              size: 48,
              color: isError ? Colors.red.withValues(alpha: 0.5) : (isDark ? Colors.white24 : Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.cairo(color: isError ? Colors.red : AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
