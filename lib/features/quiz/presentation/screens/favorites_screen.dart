import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/quiz/domain/services/list_service.dart';

class FavoritesScreen extends StatefulWidget {
  final String? listId;
  final String? listName;

  const FavoritesScreen({
    super.key,
    this.listId,
    this.listName,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  
  late Stopwatch _stopwatch;
  late Timer _timer;
  bool _isTimerRunning = false;
  bool _showAnswers = false;
  bool _isFabExpanded = false;

  final Map<String, Set<String>> _selectedOptions = {};
  final Map<String, AnswerState> _answerStates = {};
  final Set<String> _checkedQuestions = {};
  final Map<String, String> _notes = {};

  bool _showFilters = false;
  bool _filterImportant = false;
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
  }

  @override
  void dispose() {
    _timer.cancel();
    _searchController.dispose();
    super.dispose();
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

  void _checkAll(List<QueryDocumentSnapshot> docs) {
    setState(() {
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final qId = data['questionId'] as String;
        final questionMap = data['questionData'] as Map<String, dynamic>;
        final question = QuizQuestion.fromMap(questionMap, qId);
        final sel = _selectedOptions[qId] ?? {};

        if (sel.isNotEmpty) {
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

          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null && question.primaryTopicId != null) {
            DatabaseService().updateUserHistoryForSubject(
              userId,
              addWrongIds: isCorrect ? [] : [qId],
              removeWrongIds: isCorrect ? [qId] : [],
              subjectId: question.primaryTopicId!,
            );
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

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null && question.primaryTopicId != null) {
        DatabaseService().updateUserHistoryForSubject(
          userId,
          addWrongIds: isCorrect ? [] : [qId],
          removeWrongIds: isCorrect ? [qId] : [],
          subjectId: question.primaryTopicId!,
        );
      }
    });
  }

  Widget _buildExpandableFab(List<QueryDocumentSnapshot> docs) {
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
            onTap: () => _checkAll(docs),
          ),
          const SizedBox(height: 12),
          _buildFabMenuItem(
            icon: Icons.check_circle_rounded,
            label: 'تصحيح إجاباتي',
            onTap: _checkMyAnswers,
          ),
          const SizedBox(height: 12),
        ],
        Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return FloatingActionButton(
              onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
              backgroundColor: isDark ? const Color(0xFF131A26) : Colors.transparent,
              elevation: isDark ? 4 : 0,
              highlightElevation: 0,
              shape: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isDark ? null : const LinearGradient(
                    colors: [Color(0xFFCB9D80), Color(0xFF9E7E6C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  color: isDark ? const Color(0xFF131A26) : null,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: const Color(0xFF9E7E6C).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Icon(
                  _isFabExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  color: isDark ? Theme.of(context).primaryColor : Colors.white,
                ),
              ),
            );
          }
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
            child: Icon(icon, color: AppColors.primaryBlue, size: 22),
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
          color: _showFilters ? AppColors.primaryBlue.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _showFilters ? AppColors.primaryBlue : AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _showFilters ? 'إخفاء الفلاتر' : 'الفلاتر',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _showFilters ? AppColors.primaryBlue : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: _showFilters ? AppColors.primaryBlue : AppColors.textSecondary,
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
            'حسب التاريخ',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.swap_vert_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildTagButton(String label, IconData icon, bool isSelected, ValueChanged<bool> onTap) {
    return InkWell(
      onTap: () => onTap(!isSelected),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE5E2DA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول لعرض المفضلة', style: GoogleFonts.cairo())),
      );
    }

    final String listId = widget.listId ?? 'favorites';
    final String listName = widget.listName ?? 'المفضلة';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .collection('user_lists')
          .doc(listId)
          .collection('questions')
          .orderBy('savedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        
        var filteredDocs = docs;
        if (_searchQuery.isNotEmpty) {
          filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final questionMap = data['questionData'] as Map<String, dynamic>;
            final text = questionMap['text']?.toString().toLowerCase() ?? '';
            return text.contains(_searchQuery.toLowerCase());
          }).toList();
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          floatingActionButton: filteredDocs.isNotEmpty ? _buildExpandableFab(filteredDocs) : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          appBar: AppBar(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF131A26) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.cairo(),
                    decoration: InputDecoration(
                      hintText: 'البحث في $listName...',
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
                    listName,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimary),
                  ),
            centerTitle: true,
            actions: [
              _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => setState(() => _isSearching = true),
                    ),
            ],
          ),
          body: Column(
            children: [
              QuizHud(
                current: _answeredCount,
                total: filteredDocs.length,
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
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF131A26) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : AppColors.borderLight),
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
                          '${filteredDocs.length} سؤال',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.description_outlined, color: Color(0xFF1E3A8A), size: 18),
                      ],
                    ),
                  ],
                ),
              ),
              if (listId != 'favorites' && listId != 'important')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildTagButton('مهم', Icons.star, _filterImportant, (v) => setState(() => _filterImportant = v)),
                      const SizedBox(width: 8),
                      _buildTagButton('المفضلة', Icons.favorite, true, (v) {}),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : filteredDocs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                Icon(
                                  widget.listId == 'important' ? Icons.star_border_rounded : Icons.favorite_border_rounded,
                                  size: 80,
                                  color: const Color(0xFF1E3A8A),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'لا توجد أسئلة في ${widget.listName}',
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
                                    'لإضافة أسئلة، افتح أي ورقة واضغط على\nأيقونة الحفظ أو النجمة أسفل السؤال',
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
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final data = filteredDocs[index].data() as Map<String, dynamic>;
                              final qId = data['questionId'] as String;
                              final questionMap = data['questionData'] as Map<String, dynamic>;
                              final question = QuizQuestion.fromMap(questionMap, qId);

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: QuestionCard(
                                  question: question,
                                  displayIndex: index + 1,
                                  isSelected: _selectedOptions.containsKey(qId),
                                  selectedOptionIds: _selectedOptions[qId] ?? {},
                                  answerState: _answerStates[qId] ?? AnswerState.unanswered,
                                  showCorrect: _showAnswers || _checkedQuestions.contains(qId),
                                  isInPrimaryList: true,
                                  onListToggle: () {
                                    context.read<ListService>().toggleQuestionInList(listId, question);
                                  },
                                  onListLongPress: () {},
                                  listIcon: listId == 'favorites' ? Icons.favorite_rounded : (listId == 'important' ? Icons.star_rounded : Icons.list_rounded),
                                  listColor: listId == 'favorites' ? Colors.red : (listId == 'important' ? Colors.amber : AppColors.primaryBlue),
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
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
