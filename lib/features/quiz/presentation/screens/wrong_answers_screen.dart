import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';

import 'package:quizzly/features/quiz/domain/services/list_service.dart';

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
  final Map<String, Set<String>> _selectedOptions = {};
  final Map<String, AnswerState> _answerStates = {};
  final Set<String> _checkedQuestions = {};
  final Map<String, String> _notes = {};
  bool _showAnswers = false;

  final ListService _listService = ListService();
  String _primaryListId = 'favorites';
  List<UserList> _userLists = [];
  final Set<String> _primaryListIds = {};
  StreamSubscription? _userListsSubscription;
  StreamSubscription? _primaryListIdSubscription;
  StreamSubscription? _primaryListSyncSubscription;

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
    
    _userListsSubscription = _listService.streamLists().listen((lists) {
      if (mounted) setState(() => _userLists = lists);
    });
    _primaryListIdSubscription = _listService.streamPrimaryListId().listen((listId) {
      if (mounted) {
        setState(() => _primaryListId = listId);
        _setupPrimaryListSync(listId);
      }
    });
    _setupPrimaryListSync('favorites');
  }

  @override
  void dispose() {
    _timer.cancel();
    _userListsSubscription?.cancel();
    _primaryListIdSubscription?.cancel();
    _primaryListSyncSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setupPrimaryListSync(String listId) {
    _primaryListSyncSubscription?.cancel();
    _primaryListSyncSubscription = _listService.streamListQuestionIds(listId).listen((ids) {
      if (mounted) {
        setState(() {
          _primaryListIds.clear();
          _primaryListIds.addAll(ids);
        });
      }
    });
  }

  IconData _getPrimaryListIcon(bool isFilled) {
    UserList? list;
    try {
      list = _userLists.firstWhere((l) => l.id == _primaryListId);
    } catch (_) {
      list = null;
    }
    
    if (_primaryListId == 'favorites') {
      return isFilled ? Icons.favorite_rounded : Icons.favorite_border_rounded;
    } else if (_primaryListId == 'important') {
      return isFilled ? Icons.star_rounded : Icons.star_border_rounded;
    }
    
    if (list != null) {
      return IconData(list.iconCodePoint, fontFamily: 'MaterialIcons');
    }
    return isFilled ? Icons.favorite_rounded : Icons.favorite_border_rounded;
  }

  Color _getPrimaryListColor() {
    if (_primaryListId == 'favorites') return Colors.red;
    if (_primaryListId == 'important') return Colors.amber;
    return AppColors.primaryBlue;
  }

  void _showListSelectionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر القائمة السريعة', 
                style: GoogleFonts.cairo(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black
                )
              ),
              const SizedBox(height: 16),
              ..._userLists.map((list) {
                final isSelected = _primaryListId == list.id;
                return ListTile(
                  leading: Icon(
                    IconData(list.iconCodePoint, fontFamily: 'MaterialIcons'), 
                    color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white38 : AppColors.textSecondary)
                  ),
                  title: Text(
                    list.name, 
                    style: GoogleFonts.cairo(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black
                    )
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () {
                    _listService.setPrimaryListId(list.id);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      }
    );
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
        final sel = _selectedOptions[qId] ?? {};
        if (sel.isNotEmpty) {
          _checkedQuestions.add(qId);
          
          bool isCorrect = false;
          if (q.type == QuestionType.checkbox) {
            isCorrect = sel.length == q.correctOptionIds.length &&
                sel.every((id) => q.correctOptionIds.contains(id));
          } else {
            isCorrect = sel.length == 1 &&
                q.correctOptionIds.contains(sel.first);
          }
          
          _answerStates[qId] = isCorrect ? AnswerState.correct : AnswerState.wrong;
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

  void _onOptionSelected(String qId, String optionId, QuestionType type) {
    setState(() {
      final currentSet = _selectedOptions[qId] ?? <String>{};
      
      if (type == QuestionType.checkbox) {
        final newSet = Set<String>.from(currentSet);
        if (newSet.contains(optionId)) {
          newSet.remove(optionId);
        } else {
          newSet.add(optionId);
        }
        _selectedOptions[qId] = newSet;
      } else {
        _selectedOptions[qId] = {optionId};
      }
    });
  }

  void _onCheckAnswer(String qId, QuizQuestion question) {
    final sel = _selectedOptions[qId] ?? {};
    if (sel.isEmpty) return;
    
    setState(() {
      _checkedQuestions.add(qId);
      
      bool isCorrect = false;
      if (question.type == QuestionType.checkbox) {
        isCorrect = sel.length == question.correctOptionIds.length &&
            sel.every((id) => question.correctOptionIds.contains(id));
      } else {
        isCorrect = sel.length == 1 &&
            question.correctOptionIds.contains(sel.first);
      }
      
      _answerStates[qId] = isCorrect ? AnswerState.correct : AnswerState.wrong;
    });
  }

  Widget _buildExpandableFab(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isFabExpanded) ...[
          _buildFabMenuItem(
            icon: Icons.refresh_rounded,
            label: 'تصفير الإجابات',
            onTap: _resetAnswers,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildFabMenuItem(
            icon: Icons.done_all_rounded,
            label: 'تصحيح الكل',
            onTap: _checkAll,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildFabMenuItem(
            icon: Icons.check_circle_rounded,
            label: 'تصحيح إجاباتي',
            onTap: _checkMyAnswers,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12), 
                  blurRadius: 4, 
                  offset: const Offset(0, 2)
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFFDC2626), size: 22),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12), 
                  blurRadius: 4, 
                  offset: const Offset(0, 2)
                ),
              ],
            ),
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _showFilters = !_showFilters),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _showFilters 
              ? const Color(0xFFDC2626).withValues(alpha: 0.1) 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _showFilters 
                ? const Color(0xFFDC2626) 
                : (isDark ? Colors.white10 : AppColors.borderLight)
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _showFilters ? 'إخفاء الفلاتر' : 'الفلاتر',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _showFilters ? const Color(0xFFDC2626) : (isDark ? Colors.white38 : AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: _showFilters ? const Color(0xFFDC2626) : (isDark ? Colors.white38 : AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'حسب الامتحان',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.sort_rounded,
            size: 16,
            color: isDark ? Colors.white38 : AppColors.textSecondary,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      floatingActionButton: filteredQuestions.isNotEmpty ? _buildExpandableFab(isDark) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: _isSearching
            ? IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : IconButton(
                icon: Icon(Icons.search, color: isDark ? Colors.white : Colors.black),
                onPressed: () => setState(() => _isSearching = true),
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.cairo(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'البحث في الأخطاء...',
                  hintStyle: GoogleFonts.cairo(color: isDark ? Colors.white38 : Colors.grey),
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
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold, 
                  color: isDark ? Colors.white : AppColors.textPrimary
                ),
              ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, size: 20, color: isDark ? Colors.white : Colors.black),
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
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
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
                    _buildFilterButton(isDark),
                    const SizedBox(width: 8),
                    _buildSortButton(isDark),
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
                                color: isDark ? Colors.white : AppColors.textPrimary,
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
                                  color: isDark ? Colors.white38 : AppColors.textSecondary,
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
                                        isSelected: _selectedOptions.containsKey(qId),
                                        selectedOptionIds: _selectedOptions[qId] ?? {},
                                        answerState: _answerStates[qId] ?? AnswerState.unanswered,
                                        showCorrect: _showAnswers || _checkedQuestions.contains(qId),
                                        isInPrimaryList: question.id != null && _primaryListIds.contains(question.id),
                                        onListToggle: () {
                                          if (question.id != null) {
                                            _listService.toggleQuestionInList(_primaryListId, question);
                                          }
                                        },
                                        onListLongPress: () => _showListSelectionDialog(),
                                        listIcon: _getPrimaryListIcon(question.id != null && _primaryListIds.contains(question.id)),
                                        listColor: _getPrimaryListColor(),
                                        onOptionSelected: (optId) => _onOptionSelected(qId, optId, question.type),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.1) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.3) : const Color(0xFFFECACA)),
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
                color: isDark ? Colors.red[300] : const Color(0xFFDC2626),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(
          40,
          (i) => Expanded(
            child: Container(
              height: 1,
              color: i.isEven ? (isDark ? Colors.white10 : AppColors.borderLight) : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
