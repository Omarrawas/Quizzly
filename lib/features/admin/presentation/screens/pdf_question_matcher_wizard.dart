import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/core/widgets/tex_view_widget.dart';
import 'package:quizzly/core/utils/text_similarity.dart';
import 'package:quizzly/features/admin/domain/services/pdf_parsing_service.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';

class PDFQuestionMatcherWizard extends StatefulWidget {
  final List<ExtractedQuestion> extractedQuestions;
  final String subjectId;
  final String sectionId;
  final List<String> initialSelectedIds;
  final String examTitle;

  const PDFQuestionMatcherWizard({
    super.key,
    required this.extractedQuestions,
    required this.subjectId,
    required this.sectionId,
    required this.initialSelectedIds,
    required this.examTitle,
  });

  @override
  State<PDFQuestionMatcherWizard> createState() => _PDFQuestionMatcherWizardState();
}

class _PDFQuestionMatcherWizardState extends State<PDFQuestionMatcherWizard> {
  int _currentIndex = 0;
  bool _isLoadingDb = true;
  List<Map<String, dynamic>> _dbQuestions = [];
  late List<String> _selectedIds;
  
  // Suggested matches for current index
  List<Map<String, dynamic>> _suggestions = [];
  Map<String, dynamic>? _selectedMatch;
  double _bestSimilarity = 0.0;

  // Manual search
  String _manualSearchQuery = '';
  List<Map<String, dynamic>> _manualSearchResults = [];
  bool _showManualSearch = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelectedIds);
    _loadDatabaseQuestions();
  }

  Future<void> _loadDatabaseQuestions() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(DatabaseService.colQuestions)
          .where('subjectId', isEqualTo: widget.subjectId)
          .where('parentId', isEqualTo: widget.sectionId)
          .get();

      final list = snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      setState(() {
        _dbQuestions = list;
        _isLoadingDb = false;
        _calculateMatches();
      });
    } catch (e) {
      setState(() => _isLoadingDb = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل قاعدة البيانات: $e', style: GoogleFonts.cairo())),
        );
      }
    }
  }

  void _calculateMatches() {
    if (_dbQuestions.isEmpty || widget.extractedQuestions.isEmpty) return;

    final currentExtracted = widget.extractedQuestions[_currentIndex];
    
    // Calculate similarity score for each database question
    final List<Map<String, dynamic>> scored = [];
    for (var dbQ in _dbQuestions) {
      final sim = TextSimilarity.compare(currentExtracted.text, dbQ['text'] ?? '');
      scored.add({...dbQ, '_similarity': sim});
    }

    // Sort by similarity descending
    scored.sort((a, b) => (b['_similarity'] as double).compareTo(a['_similarity'] as double));

    // Keep suggestions above 25% similarity
    final filtered = scored.where((q) => (q['_similarity'] as double) >= 0.25).toList();

    setState(() {
      _suggestions = filtered;
      _bestSimilarity = filtered.isNotEmpty ? (filtered.first['_similarity'] as double) : 0.0;
      // Auto-select the best match if similarity is very high (> 75%)
      _selectedMatch = (_bestSimilarity >= 0.75) ? filtered.first : null;
      _showManualSearch = false;
      _manualSearchQuery = '';
      _manualSearchResults = [];
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.extractedQuestions.length - 1) {
      setState(() {
        _currentIndex++;
        _calculateMatches();
      });
    } else {
      _finishWizard();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _calculateMatches();
      });
    }
  }

  void _finishWizard() {
    Navigator.of(context).pop(_selectedIds);
  }

  Future<void> _addAsNewQuestion() async {
    final extracted = widget.extractedQuestions[_currentIndex];
    setState(() => _isLoadingDb = true);

    try {
      // Map options
      final optionsMap = extracted.options.map((o) => o.toMap()).toList();

      final newQuestionData = {
        'text': extracted.text,
        'type': extracted.type,
        'options': optionsMap,
        'correctOptionIds': extracted.correctOptionIds,
        'subjectId': widget.subjectId,
        'parentId': widget.sectionId,
        'difficulty': 'medium',
        'cognitiveLevel': 'understanding',
        'status': 'approved',
        'estimatedTime': 60,
        'examTags': [widget.examTitle],
        'isRepeated': false,
        'analytics': {
          'timesAnswered': 0,
          'correctAnswers': 0,
          'totalTimeSpent': 0,
          'successRate': 0.0,
          'avgTime': 0.0
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection(DatabaseService.colQuestions)
          .add(newQuestionData);

      // Add to selected list
      setState(() {
        _selectedIds.add(docRef.id);
        // Add to local list of dbQuestions so it can be matched if it appears again
        _dbQuestions.add({...newQuestionData, 'id': docRef.id});
        _isLoadingDb = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة السؤال بنجاح وتحديده للدورة')),
        );
      }

      _nextQuestion();
    } catch (e) {
      setState(() => _isLoadingDb = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء إضافة السؤال: $e', style: GoogleFonts.cairo())),
        );
      }
    }
  }

  Future<void> _updateAndSelectQuestion(Map<String, dynamic> dbQ) async {
    final extracted = widget.extractedQuestions[_currentIndex];
    setState(() => _isLoadingDb = true);

    try {
      final optionsMap = extracted.options.map((o) => o.toMap()).toList();
      final updatedData = {
        'text': extracted.text,
        'type': extracted.type,
        'options': optionsMap,
        'correctOptionIds': extracted.correctOptionIds,
      };

      await FirebaseFirestore.instance
          .collection(DatabaseService.colQuestions)
          .doc(dbQ['id'])
          .update(updatedData);

      // Update local dbQuestions list
      final idx = _dbQuestions.indexWhere((q) => q['id'] == dbQ['id']);
      if (idx != -1) {
        _dbQuestions[idx] = {..._dbQuestions[idx], ...updatedData};
      }

      setState(() {
        if (!_selectedIds.contains(dbQ['id'])) {
          _selectedIds.add(dbQ['id']);
        }
        _isLoadingDb = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث السؤال في قاعدة البيانات وتحديده')),
        );
      }

      _nextQuestion();
    } catch (e) {
      setState(() => _isLoadingDb = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تحديث السؤال: $e', style: GoogleFonts.cairo())),
        );
      }
    }
  }

  void _manualSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() => _manualSearchResults = []);
      return;
    }
    final normalizedQuery = TextSimilarity.normalizeString(query);
    final results = _dbQuestions.where((q) {
      final qText = TextSimilarity.normalizeString(q['text'] ?? '');
      return qText.contains(normalizedQuery);
    }).toList();

    setState(() {
      _manualSearchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    
    // Strictly matching Dark Fintech colors in global rules
    final Color backgroundColor = const Color(0xFF18191D);
    final Color cardColor = const Color(0xFF222329);
    final Color borderColor = const Color(0xFF2D2E36);
    final Color primaryColor = const Color(0xFF6E56FF);
    final Color secondaryColor = const Color(0xFF7DFFA2);
    final Color errorColor = const Color(0xFFFF4C6A);

    if (_isLoadingDb) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              Text(
                'جاري تحميل قاعدة بيانات الأسئلة والمطابقة...',
                style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.extractedQuestions.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          title: Text('المطابقة الذكية', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Text('لم يتم العثور على أسئلة مستخرجة.', style: GoogleFonts.tajawal(color: Colors.white54)),
        ),
      );
    }

    final currentExtracted = widget.extractedQuestions[_currentIndex];
    final progress = (_currentIndex + 1) / widget.extractedQuestions.length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المطابقة الذكية لأسئلة الـ PDF',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            Text(
              'السؤال ${_currentIndex + 1} من ${widget.extractedQuestions.length}',
              style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _finishWizard,
            icon: const Icon(Icons.done_all_rounded, color: Colors.white),
            label: Text(
              'حفظ وإنهاء (${_selectedIds.length})',
              style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Right Side Panel: Extracted Question from PDF ──
              _buildExtractedQuestionCard(currentExtracted, cardColor, borderColor, primaryColor),
              
              const SizedBox(height: 20),
              
              // Divider/Indicator
              Row(
                children: [
                  Expanded(child: Divider(color: borderColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'حالة المطابقة في قاعدة البيانات',
                      style: GoogleFonts.tajawal(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(child: Divider(color: borderColor)),
                ],
              ),
              
              const SizedBox(height: 16),

              // ── Left Side Panel: Matches / Database Actions ──
              _buildMatchSection(currentExtracted, cardColor, borderColor, primaryColor, secondaryColor, errorColor),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous Button
              ElevatedButton.icon(
                onPressed: _currentIndex > 0 ? _previousQuestion : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text('السابق', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: borderColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              
              // Skip / Next Button
              ElevatedButton.icon(
                onPressed: _nextQuestion,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  _currentIndex == widget.extractedQuestions.length - 1 ? 'إنهاء' : 'تخطي / التالي',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper to build extracted question panel ──
  Widget _buildExtractedQuestionCard(
      ExtractedQuestion q, Color cardColor, Color borderColor, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'المستخرج من PDF',
                  style: GoogleFonts.tajawal(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              _buildTypeBadge(q.type),
            ],
          ),
          const SizedBox(height: 12),
          TexViewWidget(
            text: q.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          // Options list
          ...q.options.map((opt) {
            final isCorrect = q.correctOptionIds.contains(opt.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCorrect ? const Color(0xFF00E676).withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect ? const Color(0xFF00E676).withValues(alpha: 0.4) : borderColor,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCorrect ? const Color(0xFF00E676) : borderColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      opt.id,
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TexViewWidget(
                      text: opt.text,
                      fontSize: 13,
                      color: isCorrect ? const Color(0xFF00E676) : Colors.white70,
                    ),
                  ),
                  if (isCorrect)
                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00E676), size: 16),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Helper to build matches section ──
  Widget _buildMatchSection(ExtractedQuestion q, Color cardColor, Color borderColor,
      Color primaryColor, Color secondaryColor, Color errorColor) {
    if (_showManualSearch) {
      return _buildManualSearchSection(cardColor, borderColor, primaryColor);
    }

    if (_suggestions.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: errorColor),
            const SizedBox(height: 12),
            Text(
              'لا توجد أسئلة مشابهة في قاعدة البيانات',
              style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'لم نجد أي تطابق كافٍ مع الأسئلة الحالية لهذه المادة.',
              style: GoogleFonts.tajawal(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addAsNewQuestion,
                    icon: const Icon(Icons.add_rounded),
                    label: Text('إضافة كسؤال جديد وتحديده', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _showManualSearch = true),
              icon: const Icon(Icons.search_rounded),
              label: Text('البحث يدوياً في قاعدة البيانات', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
            ),
          ],
        ),
      );
    }

    // Suggestions exist - show best suggestion or let user pick another
    final bestMatch = _selectedMatch ?? _suggestions.first;
    final similarity = bestMatch['_similarity'] as double;
    final isSelectedInExam = _selectedIds.contains(bestMatch['id']);

    Color matchColor;
    String matchLabel;
    if (similarity >= 0.85) {
      matchColor = const Color(0xFF00E676);
      matchLabel = 'تطابق ممتاز (${(similarity * 100).toStringAsFixed(0)}%)';
    } else if (similarity >= 0.50) {
      matchColor = Colors.orange;
      matchLabel = 'تطابق متوسط (${(similarity * 100).toStringAsFixed(0)}%)';
    } else {
      matchColor = Colors.grey;
      matchLabel = 'تشابه ضعيف (${(similarity * 100).toStringAsFixed(0)}%)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Suggestion Card
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelectedInExam ? secondaryColor : matchColor.withValues(alpha: 0.5)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: matchColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      matchLabel,
                      style: GoogleFonts.tajawal(
                        color: matchColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isSelectedInExam)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: secondaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_rounded, size: 10, color: secondaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'محدد للدورة',
                            style: GoogleFonts.tajawal(
                              color: secondaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TexViewWidget(
                text: bestMatch['text'] ?? '',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              // Options comparison if mcq/checkbox
              if (bestMatch['options'] != null)
                ...((bestMatch['options'] as List).map((o) {
                  final opt = Map<String, dynamic>.from(o);
                  final isCorrect = (bestMatch['correctOptionIds'] as List?)?.contains(opt['id']) ?? false;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isCorrect ? const Color(0xFF00E676) : borderColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            opt['id']?.toString() ?? '',
                            style: GoogleFonts.tajawal(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TexViewWidget(
                            text: opt['text']?.toString() ?? '',
                            fontSize: 12,
                            color: isCorrect ? const Color(0xFF00E676) : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  );
                })),
              
              const SizedBox(height: 20),

              // Action buttons for best match
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (!_selectedIds.contains(bestMatch['id'])) {
                            _selectedIds.add(bestMatch['id']);
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تحديد السؤال للدورة')),
                        );
                        _nextQuestion();
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: Text('تأكيد ومطابقة', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelectedInExam ? secondaryColor : primaryColor,
                        foregroundColor: isSelectedInExam ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateAndSelectQuestion(bestMatch),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: Text('تحديث بالـ PDF وتحديده', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addAsNewQuestion,
                      icon: const Icon(Icons.add_rounded),
                      label: Text('تجاهل المطابقة وحفظ كسؤال جديد', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white70,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: borderColor),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // List of other similar suggestions
        if (_suggestions.length > 1) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'مقترحات مشابهة أخرى:',
              style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          ..._suggestions.skip(1).take(3).map((dbQ) {
            final sim = dbQ['_similarity'] as double;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: ListTile(
                title: TexViewWidget(text: dbQ['text'] ?? '', fontSize: 12, color: Colors.white70),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'نسبة التشابه: ${(sim * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.tajawal(fontSize: 10, color: Colors.grey),
                  ),
                ),
                trailing: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedMatch = dbQ;
                    });
                  },
                  child: Text('عرض المقترح', style: GoogleFonts.tajawal(color: primaryColor, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _showManualSearch = true),
            icon: const Icon(Icons.search_rounded),
            label: Text('البحث اليدوي عن هذا السؤال', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(foregroundColor: Colors.white54),
          ),
        ),
      ],
    );
  }

  // ── Helper to build manual search UI ──
  Widget _buildManualSearchSection(Color cardColor, Color borderColor, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'البحث اليدوي في قاعدة البيانات',
                style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _showManualSearch = false),
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: _manualSearch,
            style: GoogleFonts.tajawal(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'اكتب الكلمات الرئيسية للبحث...',
              hintStyle: GoogleFonts.tajawal(fontSize: 12, color: Colors.white30),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primaryColor),
              ),
              fillColor: Colors.black26,
              filled: true,
            ),
          ),
          const SizedBox(height: 16),
          if (_manualSearchResults.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _manualSearchResults.length,
                itemBuilder: (context, index) {
                  final dbQ = _manualSearchResults[index];
                  final isSelected = _selectedIds.contains(dbQ['id']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? primaryColor : borderColor),
                    ),
                    child: ListTile(
                      title: TexViewWidget(text: dbQ['text'] ?? '', fontSize: 12, color: Colors.white70),
                      trailing: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedMatch = dbQ;
                            _showManualSearch = false;
                          });
                        },
                        child: Text(
                          'تحديد كمطابق',
                          style: GoogleFonts.tajawal(color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else if (_manualSearchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('لا توجد نتائج للبحث اليدوي', style: GoogleFonts.tajawal(color: Colors.white30)),
              ),
            ),
        ],
      ),
    );
  }

  // Helper type badge
  Widget _buildTypeBadge(String type) {
    String typeStr = 'اختيار';
    Color typeColor = Colors.blue;
    switch (type) {
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
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.15),
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
    );
  }
}
