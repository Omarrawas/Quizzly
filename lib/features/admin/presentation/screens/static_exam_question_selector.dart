import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/core/widgets/zoomable_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:quizzly/features/admin/domain/services/pdf_parsing_service.dart';
import 'package:quizzly/features/admin/presentation/screens/pdf_question_matcher_wizard.dart';
import 'package:quizzly/features/admin/presentation/screens/question_management_screen.dart';

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

  // Filters State
  bool _isFilterVisible = false;
  String _repetitionFilter = 'all'; // 'all', 'high', 'medium', 'low', 'none'
  List<String> _availableExams = [];
  String _selectedExamFilter = 'all'; // 'all' or specific exam title

  // Topic hierarchy: chapters → lessons
  List<Map<String, dynamic>> _chapters = [];
  Map<String, List<Map<String, dynamic>>> _lessonsByChapter = {};
  bool _isLoadingTopics = true;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelectedIds);
    _loadTopics();
    _loadAvailableExams();
  }

  void _loadAvailableExams() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(DatabaseService.colExams)
          .where('subjectId', isEqualTo: widget.subjectId)
          .get();
      
      final exams = snap.docs
          .map((d) => (d.data()['title'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
      
      exams.sort();
      if (mounted) {
        setState(() {
          _availableExams = exams;
        });
      }
    } catch (e) {
      debugPrint('Error loading exams for filter: $e');
    }
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

  Future<void> _startPdfImport() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      final bytes = result.files.single.bytes!;

      if (!mounted) return;
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222329) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D2E36) : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6E56FF)),
                  const SizedBox(height: 16),
                  Text(
                    'جاري استخراج أسئلة الـ PDF وتفسيرها ذكياً...',
                    style: GoogleFonts.tajawal(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final parsingService = PDFParsingService();
      final extracted = await parsingService.parsePDF(
        bytes,
        subjectId: widget.subjectId,
        sectionId: widget.sectionId,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (extracted.isEmpty) {
        throw Exception('لم يتم العثور على أي أسئلة مستخرجة صالحة.');
      }

      if (!mounted) return;

      final List<String>? updatedIds = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (context) => PDFQuestionMatcherWizard(
            extractedQuestions: extracted,
            subjectId: widget.subjectId,
            sectionId: widget.sectionId,
            initialSelectedIds: _selectedIds,
            examTitle: widget.examTitle,
          ),
        ),
      );

      if (updatedIds != null) {
        setState(() {
          _selectedIds = updatedIds;
        });
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context); // Safe dismiss of dialog if open
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء الاستيراد: ${e.toString().replaceAll('Exception:', '').trim()}',
              style: GoogleFonts.tajawal(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _startTextImport() async {
    final textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF222329) : Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? const Color(0xFF2D2E36) : Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            title: Text(
              'استيراد ذكي من نص مكتوب',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'انسخ نص الاختبار الذي يحتوي على الأسئلة والصقها هنا. سيقوم الذكاء الاصطناعي بتحليل النص واستخراج الأسئلة وتحديد الإجابات الصحيحة.',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 8,
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ألصق نص الاختبار هنا...',
                      hintStyle: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF18191D) : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF2D2E36) : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF6E56FF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final enteredText = textController.text.trim();
                  if (enteredText.isNotEmpty) {
                    Navigator.pop(context, enteredText);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6E56FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'تحليل وتفسير',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (text == null || text.isEmpty) return;

    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222329) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2D2E36) : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF6E56FF)),
                const SizedBox(height: 16),
                Text(
                  'جاري استخراج الأسئلة وتفسيرها ذكياً...',
                  style: GoogleFonts.tajawal(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final parsingService = PDFParsingService();
      final extracted = await parsingService.parseText(text);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (extracted.isEmpty) {
        throw Exception('لم يتم العثور على أي أسئلة مستخرجة صالحة.');
      }

      if (!mounted) return;

      final List<String>? updatedIds = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (context) => PDFQuestionMatcherWizard(
            extractedQuestions: extracted,
            subjectId: widget.subjectId,
            sectionId: widget.sectionId,
            initialSelectedIds: _selectedIds,
            examTitle: widget.examTitle,
          ),
        ),
      );

      if (updatedIds != null) {
        setState(() {
          _selectedIds = updatedIds;
        });
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context); // Safe dismiss of dialog if open
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء الاستيراد: ${e.toString().replaceAll('Exception:', '').trim()}',
              style: GoogleFonts.tajawal(),
            ),
          ),
        );
      }
    }
  }

  void _addNewQuestion() {
    final selectedLessonName = _selectedTopicId != null ? _getTopicName(_selectedTopicId!) : null;
    Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionManagementScreen(
          sectionId: widget.sectionId,
          subjectId: widget.subjectId,
          lessonId: _selectedTopicId,
          lessonName: selectedLessonName,
        ),
      ),
    ).then((newQuestionId) {
      if (newQuestionId != null && mounted) {
        setState(() {
          if (!_selectedIds.contains(newQuestionId)) {
            _selectedIds.add(newQuestionId);
          }
        });
      }
    });
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
                style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.examTitle, style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isFilterVisible ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded),
            tooltip: _isFilterVisible ? 'إغلاق الفلاتر' : 'الفلاتر',
            onPressed: () {
              setState(() {
                _isFilterVisible = !_isFilterVisible;
              });
            },
          ),
          IconButton(
            tooltip: 'إضافة سؤال جديد',
            onPressed: _addNewQuestion,
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6E56FF)),
          ),
          PopupMenuButton<String>(
            tooltip: 'استيراد ذكي للأسئلة',
            icon: const Icon(Icons.auto_awesome, color: AppColors.primaryBlue),
            onSelected: (value) {
              if (value == 'pdf') {
                _startPdfImport();
              } else if (value == 'text') {
                _startTextImport();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'استيراد من PDF',
                      style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'text',
                child: Row(
                  children: [
                    const Icon(Icons.text_fields_rounded, size: 20, color: Color(0xFF6E56FF)),
                    const SizedBox(width: 8),
                    Text(
                      'استيراد من نص مكتوب',
                      style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _saveSelection,
            child: Text(
              'حفظ (${_selectedIds.length})',
              style: GoogleFonts.tajawal(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark),
          _buildTopicClassifier(isDark),
          _buildSearchAndFilter(isDark),
          Expanded(child: _buildQuestionsList(isDark)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    if (!_isFilterVisible) return const SizedBox.shrink();

    return Column(
      children: [
        // Repetition Filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تكرار الأسئلة',
                style: GoogleFonts.tajawal(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRepetitionChip('الكل', 'all', isDark),
                    const SizedBox(width: 8),
                    _buildRepetitionChip('مكرر جداً (4+)', 'high', isDark, activeColor: Colors.purple),
                    const SizedBox(width: 8),
                    _buildRepetitionChip('مكرر بشكل متوسط (3)', 'medium', isDark, activeColor: Colors.orange),
                    const SizedBox(width: 8),
                    _buildRepetitionChip('مكرر (2)', 'low', isDark, activeColor: Colors.red),
                    const SizedBox(width: 8),
                    _buildRepetitionChip('غير مكرر', 'none', isDark, activeColor: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Exams/Doras Filter
        if (_availableExams.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تصفية حسب الدورة',
                  style: GoogleFonts.tajawal(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip(
                        label: 'الكل',
                        isSelected: _selectedExamFilter == 'all',
                        onSelected: () => setState(() => _selectedExamFilter = 'all'),
                        isDark: isDark,
                      ),
                      ..._availableExams.map((exam) {
                        return _buildFilterChip(
                          label: exam,
                          isSelected: _selectedExamFilter == exam,
                          onSelected: () => setState(() => _selectedExamFilter = exam),
                          isDark: isDark,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildRepetitionChip(String label, String value, bool isDark, {Color? activeColor}) {
    bool isSelected = _repetitionFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _repetitionFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (activeColor ?? const Color(0xFF6E56FF)) 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 12,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: const Color(0xFF6E56FF),
        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
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
          hintStyle: GoogleFonts.tajawal(fontSize: 14),
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

    // Prepare dropdown items
    final List<DropdownMenuItem<String?>> items = [];
    
    // Default item
    items.add(DropdownMenuItem<String?>(
      value: null,
      child: Text(
        'جميع الفصول والمواضيع',
        style: GoogleFonts.tajawal(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
    ));

    for (var chapter in _chapters) {
      final chapterId = chapter['id'] as String;
      final chapterName = chapter['name'] as String? ?? '';
      final lessons = _lessonsByChapter[chapterId] ?? [];

      items.add(DropdownMenuItem<String?>(
        value: chapterId,
        child: Text(
          'الفصل: $chapterName',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ));

      for (var lesson in lessons) {
        final lessonId = lesson['id'] as String;
        final lessonName = lesson['name'] as String? ?? '';

        items.add(DropdownMenuItem<String?>(
          value: lessonId,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0), // Indent lessons in RTL
            child: Text(
              '← الدرس: $lessonName',
              style: GoogleFonts.tajawal(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ));
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedTopicId,
          isExpanded: true,
          hint: Text(
            'اختر الفصل أو الدرس للتصفية',
            style: GoogleFonts.tajawal(fontSize: 14),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: items,
          onChanged: (String? value) {
            setState(() {
              _selectedTopicId = value;
            });
          },
        ),
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

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .trim();
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

        // Filter docs
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Search Filter
          if (_searchQuery.isNotEmpty) {
            final text = _stripHtml(data['text']?.toString() ?? '').toLowerCase();
            if (!text.contains(_searchQuery)) return false;
          }

          // Repetition Filter
          if (_repetitionFilter != 'all') {
            final examTags = (data['examTags'] as List?) ?? [];
            final count = examTags.length;
            if (_repetitionFilter == 'high' && count < 4) return false;
            if (_repetitionFilter == 'medium' && count != 3) return false;
            if (_repetitionFilter == 'low' && count != 2) return false;
            if (_repetitionFilter == 'none' && count > 1) return false;
          }

          // Exam/Dora Filter
          if (_selectedExamFilter != 'all') {
            final examTags = (data['examTags'] as List?) ?? [];
            if (!examTags.contains(_selectedExamFilter)) return false;
          }

          return true;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text('لا توجد أسئلة تطابق البحث أو الفلاتر', style: GoogleFonts.tajawal()),
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

            final String typeStr;
            final Color typeColor;
            switch (data['type']) {
              case 'mcq':
                typeStr = 'اختيار';
                typeColor = Colors.blue;
                break;
              case 'tf':
                typeStr = 'صح/خطأ';
                typeColor = Colors.teal;
                break;
              case 'checkbox':
                typeStr = 'مربعات اختيار';
                typeColor = Colors.purple;
                break;
              case 'essay':
                typeStr = 'مقالي';
                typeColor = Colors.orange;
                break;
              default:
                typeStr = 'اختيار';
                typeColor = Colors.blue;
            }
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
                                    style: GoogleFonts.tajawal(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: typeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TexViewWidget(
                                    text: data['text'] ?? '',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white : AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                            if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ZoomableImage(
                                imageUrl: data['imageUrl'].toString(),
                                height: 80,
                                fit: BoxFit.contain,
                              ),
                            ],
                            if (data['options'] != null && (data['options'] as List).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...((data['options'] as List).map((o) {
                                final opt = Map<String, dynamic>.from(o);
                                final optId = opt['id']?.toString() ?? '';
                                final optText = opt['text']?.toString() ?? '';
                                final correctOptionIds = (data['correctOptionIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
                                final isCorrect = correctOptionIds.contains(optId);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isCorrect ? const Color(0xFF00E676) : (isDark ? Colors.white12 : Colors.grey[300]),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          optId,
                                          style: GoogleFonts.tajawal(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isCorrect ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TexViewWidget(
                                          text: optText,
                                          fontSize: 11,
                                          color: isCorrect
                                              ? const Color(0xFF00E676)
                                              : (isSelected
                                                  ? AppColors.primaryBlue.withValues(alpha: 0.8)
                                                  : (isDark ? Colors.white60 : Colors.grey[700])),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })),
                            ],
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
                                        style: GoogleFonts.tajawal(
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
                                    style: GoogleFonts.tajawal(
                                        fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                                // Repeated badge
                                if (isRepeated)
                                  Builder(
                                    builder: (context) {
                                      final count = examTags.length;
                                      String label = 'مكرر';
                                      Color color = Colors.red;
                                      if (count >= 4) {
                                        label = 'مكرر جداً';
                                        color = Colors.purple;
                                      } else if (count == 3) {
                                        label = 'مكرر بشكل متوسط';
                                        color = Colors.orange;
                                      }
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: color.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.repeat_rounded, size: 9, color: color),
                                            const SizedBox(width: 3),
                                            Text(
                                              label,
                                              style: GoogleFonts.tajawal(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
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
                                        style: GoogleFonts.tajawal(
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

