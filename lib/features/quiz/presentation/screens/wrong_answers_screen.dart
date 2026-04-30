import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';

class WrongAnswersScreen extends StatefulWidget {
  final String? subjectId;
  final String subjectName;

  const WrongAnswersScreen({
    super.key,
    this.subjectId,
    this.subjectName = 'الكيمياء',
  });

  @override
  State<WrongAnswersScreen> createState() => _WrongAnswersScreenState();
}

class _WrongAnswersScreenState extends State<WrongAnswersScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  
  bool _isLoading = true;
  List<QuizQuestion> _wrongQuestions = [];
  Map<String, List<QuizQuestion>> _groupedQuestions = {};
  List<String> _orderedExams = [];

  // Stopwatch & HUD
  late Stopwatch _stopwatch;
  late Timer _timer;
  bool _isTimerRunning = false;

  // Answers state
  final Map<String, String?> _selectedOptions = {};
  final Map<String, AnswerState> _answerStates = {};
  final Set<String> _checkedQuestions = {};
  final Map<String, String> _notes = {};
  final Set<String> _favorites = {};
  bool _showAnswers = false;

  // FAB
  bool _isFabExpanded = false;

  // Filters
  bool _showFilters = false;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  int get _correctCount => _answerStates.values.where((s) => s == AnswerState.correct).length;
  int get _wrongCount => _answerStates.values.where((s) => s == AnswerState.wrong).length;
  int get _answeredCount => _checkedQuestions.length;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isTimerRunning) setState(() {});
    });
    _fetchWrongQuestions();
    _fetchFavorites();
  }

  @override
  void dispose() {
    _timer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFavorites() async {
    if (_user == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(_user.uid).collection('favorites').get();
      if (mounted) {
        setState(() {
          for (var doc in snap.docs) {
            _favorites.add(doc.id);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
    }
  }

  Future<void> _fetchWrongQuestions() async {
    if (_user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('user_history').doc(_user.uid).get();
      if (!doc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final String wrongField = widget.subjectId != null ? 'wrongAnswers_${widget.subjectId}' : 'wrongAnswers';
      final List<String> subjectIds = List<String>.from(doc.data()?[wrongField] ?? []);
      final List<String> globalIds = List<String>.from(doc.data()?['wrongAnswers'] ?? []);
      
      // Combine for initial display
      final Set<String> allIdsSet = {...subjectIds, ...globalIds};
      final List<String> wrongIds = allIdsSet.toList();
      
      if (wrongIds.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      List<QuizQuestion> questions = [];
      List<String> idsToMigrate = [];

      for (var i = 0; i < wrongIds.length; i += 30) {
        final chunk = wrongIds.sublist(i, i + 30 > wrongIds.length ? wrongIds.length : i + 30);
        
        Query query = FirebaseFirestore.instance.collection('questions')
            .where(FieldPath.documentId, whereIn: chunk);
            
        if (widget.subjectId != null) {
          query = query.where('subjectId', isEqualTo: widget.subjectId);
        }
        
        final snap = await query.get();
        for (var d in snap.docs) {
          final q = QuizQuestion.fromMap(d.data() as Map<String, dynamic>, d.id);
          questions.add(q);
          
          // If this ID was found in global but not subject list, mark for migration
          if (globalIds.contains(q.id) && !subjectIds.contains(q.id)) {
            idsToMigrate.add(q.id!);
          }
        }
      }

      // Perform stealth migration if needed
      if (idsToMigrate.isNotEmpty && widget.subjectId != null) {
        _performStealthMigration(idsToMigrate);
      }

      _groupAndSortQuestions(questions);

    } catch (e) {
      debugPrint('Error fetching wrong questions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performStealthMigration(List<String> ids) async {
    try {
      final String wrongField = 'wrongAnswers_${widget.subjectId}';
      await FirebaseFirestore.instance.collection('user_history').doc(_user!.uid).update({
        wrongField: FieldValue.arrayUnion(ids),
        'wrongAnswers': FieldValue.arrayRemove(ids),
      });
      debugPrint('Successfully migrated ${ids.length} questions to subject pool');
    } catch (e) {
      debugPrint('Migration failed: $e');
    }
  }

  void _groupAndSortQuestions(List<QuizQuestion> questions) {
    final grouped = <String, List<QuizQuestion>>{};
    for (var q in questions) {
      final groupName = (q.tagLabel != null && q.tagLabel!.isNotEmpty) ? q.tagLabel! : 'بدون تصنيف';
      grouped.putIfAbsent(groupName, () => []).add(q);
    }
    
    setState(() {
      _wrongQuestions = questions;
      _groupedQuestions = grouped;
      _orderedExams = grouped.keys.toList()..sort();
      _isLoading = false;
    });
  }

  void _toggleTimer() {
    setState(() {
      if (_isTimerRunning) {
        _stopwatch.stop();
      } else {
        _stopwatch.start();
      }
      _isTimerRunning = !_isTimerRunning;
    });
  }

  void _resetAnswers() {
    setState(() {
      _selectedOptions.clear();
      _answerStates.clear();
      _checkedQuestions.clear();
      _showAnswers = false;
      _isFabExpanded = false;
      _stopwatch.reset();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تصفير كافة الإجابات', textAlign: TextAlign.right)),
    );
  }

  void _checkAll() {
    setState(() {
      for (var q in _wrongQuestions) {
        final qId = q.id ?? q.number.toString();
        if (_selectedOptions[qId] != null) {
          _checkedQuestions.add(qId);
          final selectedId = _selectedOptions[qId];
          if (q.correctOptionIds.contains(selectedId)) {
            _answerStates[qId] = AnswerState.correct;
          } else {
            _answerStates[qId] = AnswerState.wrong;
          }
        }
      }
      _isFabExpanded = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تصحيح كافة الأسئلة المجابة', textAlign: TextAlign.right)),
    );
  }

  void _checkMyAnswers() {
    setState(() {
      _showAnswers = true;
      _isFabExpanded = false;
    });
  }

  void _onOptionSelected(String qId, String optionId) {
    setState(() {
      _selectedOptions[qId] = optionId;
    });
  }

  void _onCheckAnswer(String qId, QuizQuestion question) {
    if (_selectedOptions[qId] == null) return;
    
    setState(() {
      _checkedQuestions.add(qId);
      final selectedId = _selectedOptions[qId];
      if (question.correctOptionIds.contains(selectedId)) {
        _answerStates[qId] = AnswerState.correct;
      } else {
        _answerStates[qId] = AnswerState.wrong;
      }
    });
  }

  Widget _buildExpandableFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isFabExpanded) ...[
          _buildFabMenuItem(
            icon: Icons.refresh_rounded,
            label: 'تصفير الإجابات',
            onTap: _resetAnswers,
          ),
          const SizedBox(height: 12),
          _buildFabMenuItem(
            icon: Icons.done_all_rounded,
            label: 'تصحيح الكل',
            onTap: _checkAll,
          ),
          const SizedBox(height: 12),
          _buildFabMenuItem(
            icon: Icons.check_circle_rounded,
            label: 'تصحيح إجاباتي',
            onTap: _checkMyAnswers,
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
          backgroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(),
          child: Icon(
            _isFabExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
            color: const Color(0xFFDC2626), // Red for wrong answers
          ),
        ),
      ],
    );
  }

  Widget _buildFabMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Icon(icon, color: const Color(0xFFDC2626), size: 22),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return InkWell(
      onTap: () => setState(() => _showFilters = !_showFilters),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _showFilters ? const Color(0xFFDC2626).withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _showFilters ? const Color(0xFFDC2626) : AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _showFilters ? 'إخفاء الفلاتر' : 'الفلاتر',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _showFilters ? const Color(0xFFDC2626) : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: _showFilters ? const Color(0xFFDC2626) : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'حسب الامتحان',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.sort_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول', style: GoogleFonts.cairo())),
      );
    }

    // Filter questions based on search
    final filteredQuestions = _searchQuery.isEmpty 
        ? _wrongQuestions 
        : _wrongQuestions.where((q) => q.text.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: filteredQuestions.isNotEmpty ? _buildExpandableFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.search, color: Colors.black),
                onPressed: () => setState(() => _isSearching = true),
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.cairo(),
                decoration: InputDecoration(
                  hintText: 'البحث في الأخطاء...',
                  hintStyle: GoogleFonts.cairo(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Text(
                'الإجابات الخاطئة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          QuizHud(
            current: _answeredCount,
            total: filteredQuestions.length,
            correctCount: _correctCount,
            wrongCount: _wrongCount,
            elapsed: _stopwatch.elapsed,
            isTimerRunning: _isTimerRunning,
            onToggleTimer: _toggleTimer,
            onCorrectTap: () {},
            onWrongTap: () {},
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildFilterButton(),
                    const SizedBox(width: 8),
                    _buildSortButton(),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${filteredQuestions.length} سؤال',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 18),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredQuestions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            const Icon(Icons.check_circle_outline_rounded, size: 80, color: Color(0xFF16A34A)),
                            const SizedBox(height: 24),
                            Text(
                              'لا توجد أخطاء مسجلة',
                              style: GoogleFonts.cairo(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'ممتاز! لقد أجبت على جميع الأسئلة بشكل صحيح حتى الآن.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: _orderedExams.length,
                        itemBuilder: (context, sectionIndex) {
                          final examName = _orderedExams[sectionIndex];
                          final questionsInSection = _groupedQuestions[examName]!;
                          
                          // Filter questions for this section
                          final filteredSection = _searchQuery.isEmpty 
                              ? questionsInSection 
                              : questionsInSection.where((q) => q.text.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

                          if (filteredSection.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ExamBreadcrumb(examTitle: examName),
                              ...filteredSection.map((question) {
                                final qId = question.id ?? question.number.toString();
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      child: QuestionCard(
                                        question: question,
                                        isSelected: _selectedOptions[qId] != null,
                                        selectedOptionId: _selectedOptions[qId],
                                        answerState: _answerStates[qId] ?? AnswerState.unanswered,
                                        showCorrect: _showAnswers || _checkedQuestions.contains(qId),
                                        isFavorite: _favorites.contains(qId),
                                        onFavoriteToggle: () async {
                                          final user = FirebaseAuth.instance.currentUser;
                                          if (user == null) return;
                                          final favoritesRef = FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user.uid)
                                              .collection('favorites');

                                          setState(() {
                                            if (_favorites.contains(qId)) {
                                              _favorites.remove(qId);
                                              favoritesRef.doc(qId).delete();
                                            } else {
                                              _favorites.add(qId);
                                              favoritesRef.doc(qId).set({
                                                'questionId': qId,
                                                'savedAt': FieldValue.serverTimestamp(),
                                                'questionData': question.toMap(),
                                              });
                                            }
                                          });
                                        },
                                        onOptionSelected: (optId) => _onOptionSelected(qId, optId),
                                        note: _notes[qId],
                                        onNoteChanged: (note) {
                                          setState(() {
                                            _notes[qId] = note;
                                          });
                                        },
                                        onCheckAnswer: () => _onCheckAnswer(qId, question),
                                        isChecked: _checkedQuestions.contains(qId),
                                      ),
                                    ),
                                    const _QuestionDivider(),
                                  ],
                                );
                              }),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Exam Breadcrumb (Section Header)
// ─────────────────────────────────────────
class _ExamBreadcrumb extends StatelessWidget {
  final String examTitle;
  const _ExamBreadcrumb({required this.examTitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_rounded, size: 16, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text(
              examTitle,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Divider between questions
// ─────────────────────────────────────────
class _QuestionDivider extends StatelessWidget {
  const _QuestionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(
          40,
          (i) => Expanded(
            child: Container(
              height: 1,
              color: i.isEven ? AppColors.borderLight : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
