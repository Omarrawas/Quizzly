import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';

class StaticExamQuestionSelector extends StatefulWidget {
  final String examId;
  final String examTitle;
  final String subjectId;
  final List<String> initialSelectedIds;

  const StaticExamQuestionSelector({
    super.key,
    required this.examId,
    required this.examTitle,
    required this.subjectId,
    required this.initialSelectedIds,
  });

  @override
  State<StaticExamQuestionSelector> createState() => _StaticExamQuestionSelectorState();
}

class _StaticExamQuestionSelectorState extends State<StaticExamQuestionSelector> {
  late List<String> _selectedIds;
  String _searchQuery = '';
  String? _selectedTopicId;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelectedIds);
  }

  Future<void> _saveSelection() async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // 1. Get Exam Details to get the Category/Tag name
      final examSnap = await FirebaseFirestore.instance.collection(DatabaseService.colExams).doc(widget.examId).get();
      final examData = examSnap.data() ?? {};
      final tagName = examData['category'] ?? widget.examTitle;
      
      // 2. Update Exam
      batch.update(
        FirebaseFirestore.instance.collection(DatabaseService.colExams).doc(widget.examId), 
        {
          'staticQuestions': _selectedIds,
          'totalQuestions': _selectedIds.length,
          'duration': _selectedIds.length * 60, // Auto-calculate duration: 60s per question
        }
      );

      // 3 & 4. Handle Tags for modified questions
      final allAffectedIds = {..._selectedIds, ...widget.initialSelectedIds};
      
      for (var id in allAffectedIds) {
        final qSnap = await FirebaseFirestore.instance.collection(DatabaseService.colQuestions).doc(id).get();
        final qData = qSnap.data() ?? {};
        List<String> currentTags = List<String>.from(qData['examTags'] ?? []);
        
        if (_selectedIds.contains(id)) {
          if (!currentTags.contains(tagName)) currentTags.add(tagName);
        } else {
          currentTags.remove(tagName);
        }

        batch.update(
          FirebaseFirestore.instance.collection(DatabaseService.colQuestions).doc(id),
          {
            'examTags': currentTags,
            'isRepeated': currentTags.length > 1,
          }
        );
      }

      await batch.commit();
      
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('تم تحديث أسئلة الاختبار والأوسمة بنجاح')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء الحفظ: $e')),
      );
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
            Text('تحديد أسئلة الاختبار', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.examTitle, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saveSelection,
            child: Text('حفظ (${_selectedIds.length})', style: GoogleFonts.cairo(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(isDark),
          Expanded(child: _buildQuestionsList(isDark)),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      child: Column(
        children: [
          TextField(
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
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(DatabaseService.colTopics)
                .where('subjectId', isEqualTo: widget.subjectId)
                .orderBy('order')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final topics = snapshot.data!.docs;
              return DropdownButtonFormField<String>(
                initialValue: _selectedTopicId,
                isExpanded: true,
                hint: Text('تصفية حسب الموضوع', style: GoogleFonts.cairo(fontSize: 12)),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  fillColor: isDark ? Colors.black26 : Colors.white,
                  filled: true,
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text('جميع المواضيع', style: GoogleFonts.cairo(fontSize: 12))),
                  ...topics.map((t) {
                    final data = t.data() as Map<String, dynamic>;
                    final prefix = data['type'] == 'chapter' ? '' : (data['type'] == 'lesson' ? '  - ' : '    -- ');
                    return DropdownMenuItem(
                      value: t.id,
                      child: Text(prefix + data['name'], style: GoogleFonts.cairo(fontSize: 12)),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => _selectedTopicId = v),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList(bool isDark) {
    Query query = FirebaseFirestore.instance
        .collection(DatabaseService.colQuestions)
        .where('subjectId', isEqualTo: widget.subjectId);

    if (_selectedTopicId != null) {
      query = query.where('topicId', isEqualTo: _selectedTopicId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
        
        var docs = snapshot.data?.docs ?? [];
        
        // Local filtering for search query
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final text = (doc.data() as Map<String, dynamic>)['text']?.toString().toLowerCase() ?? '';
            return text.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(child: Text('لا توجد أسئلة تطابق البحث', style: GoogleFonts.cairo()));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final id = doc.id;
            final isSelected = _selectedIds.contains(id);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedIds.add(id);
                    } else {
                      _selectedIds.remove(id);
                    }
                  });
                },
                title: Text(data['text'] ?? '', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'النوع: ${data['type']} | الصعوبة: ${data['difficulty']}',
                  style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                ),
                activeColor: AppColors.primaryBlue,
                checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            );
          },
        );
      },
    );
  }
}
