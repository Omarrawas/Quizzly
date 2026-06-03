import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';
import 'package:quizzly/features/quiz/domain/services/spaced_repetition_service.dart';
import 'package:quizzly/features/quiz/domain/services/list_service.dart';


class QuizScreen extends StatefulWidget {
  final QuizExam exam;
  final bool wrongAnswersMode;

  const QuizScreen({
    super.key,
    required this.exam,
    this.wrongAnswersMode = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // ── State ────────────────────────────────────────────
  int _currentIndex = 0;
  final Map<int, Set<String>> _selectedAnswers = {};
  final Map<int, AnswerState> _answerStates = {};
  final Set<int> _revealed = {}; // which questions have been checked
  final Map<int, String> _notes = {};
  final SpacedRepetitionService _srsService = SpacedRepetitionService();
  final ListService _listService = ListService();

  String _primaryListId = 'favorites';
  List<UserList> _userLists = [];
  final Set<String> _primaryListIds = {};
  StreamSubscription? _userListsSubscription;
  StreamSubscription? _primaryListIdSubscription;
  StreamSubscription? _primaryListSyncSubscription;

  // Timer
  bool _timerRunning = true;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // Counters
  int get _correct =>
      _answerStates.values.where((s) => s == AnswerState.correct).length;
  int get _wrong =>
      _answerStates.values.where((s) => s == AnswerState.wrong).length;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadInitialData();
    
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

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.exam.subjectId.isEmpty) return;

    try {
      final subjectData = await _srsService.getAllSubjectData(user.uid, widget.exam.subjectId);
        setState(() {
          for (int i = 0; i < widget.exam.questions.length; i++) {
            final q = widget.exam.questions[i];
            final qId = q.id ?? q.number.toString();
            
            if (subjectData.containsKey(qId)) {
              final note = subjectData[qId]!['note'];
              if (note != null) _notes[i] = note;
            }
          }
        });
    } catch (e) {
      debugPrint('Error loading initial quiz data: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _userListsSubscription?.cancel();
    _primaryListIdSubscription?.cancel();
    _primaryListSyncSubscription?.cancel();
    super.dispose();
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('اختر القائمة السريعة', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._userLists.map((list) {
                return ListTile(
                  leading: Icon(IconData(list.iconCodePoint, fontFamily: 'MaterialIcons'), color: _primaryListId == list.id ? AppColors.primaryBlue : AppColors.textSecondary),
                  title: Text(list.name, style: GoogleFonts.cairo(fontWeight: _primaryListId == list.id ? FontWeight.bold : FontWeight.normal)),
                  trailing: _primaryListId == list.id ? const Icon(Icons.check_circle, color: Colors.green) : null,
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

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timerRunning && mounted) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
  }

  void _toggleTimer() {
    HapticFeedback.selectionClick();
    setState(() => _timerRunning = !_timerRunning);
  }

  // ── Scroll controller ────────────────────────────────
  final ScrollController _scrollController = ScrollController();

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── HUD
          QuizHud(
            current: _currentIndex + 1,
            total: widget.exam.questions.length,
            correctCount: _correct,
            wrongCount: _wrong,
            elapsed: _elapsed,
            isTimerRunning: _timerRunning,
            onToggleTimer: _toggleTimer,
          ),
          const Divider(height: 1),
          // ── Scrollable content
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: widget.exam.questions.length + 1, // +1 for header
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      QuizExamHeader(exam: widget.exam),
                      const SizedBox(height: 4),
                    ],
                  );
                }
                final qIndex = i - 1;
                final question = widget.exam.questions[qIndex];
                final selected = _selectedAnswers[qIndex];
                final state = _answerStates[qIndex] ?? AnswerState.unanswered;
                final showCorrect = _revealed.contains(qIndex);

                return Column(
                  children: [
                    QuestionCard(
                      question: question,
                      selectedOptionIds: selected ?? {},
                      answerState: state,
                      showCorrect: showCorrect,
                      isInPrimaryList: question.id != null && _primaryListIds.contains(question.id),
                      onListToggle: () {
                        if (question.id != null) {
                          _listService.toggleQuestionInList(_primaryListId, question);
                        }
                      },
                      onListLongPress: () => _showListSelectionDialog(),
                      listIcon: _getPrimaryListIcon(question.id != null && _primaryListIds.contains(question.id)),
                      listColor: _getPrimaryListColor(),
                      onCheckAnswer: () {
                         final sel = _selectedAnswers[qIndex] ?? {};
                         if (sel.isEmpty) return;
                         HapticFeedback.mediumImpact();
                         setState(() {
                           _revealed.add(qIndex);
                           
                           // Validation for multi-select vs single
                           bool isCorrect = false;
                           if (question.type == QuestionType.checkbox) {
                             // Must match exactly
                             isCorrect = sel.length == question.correctOptionIds.length &&
                                 sel.every((id) => question.correctOptionIds.contains(id));
                           } else {
                             // Single choice
                             isCorrect = sel.length == 1 &&
                                 question.correctOptionIds.contains(sel.first);
                           }

                           _answerStates[qIndex] = isCorrect
                               ? AnswerState.correct
                               : AnswerState.wrong;

                          // Sync with global history
                          final userId = FirebaseAuth.instance.currentUser?.uid;
                          if (userId != null && widget.exam.subjectId.isNotEmpty) {
                            final qId = question.id ?? question.number.toString();
                            DatabaseService().updateUserHistoryForSubject(
                              userId,
                              addWrongIds: isCorrect ? [] : [qId],
                              removeWrongIds: isCorrect ? [qId] : [],
                              subjectId: widget.exam.subjectId,
                            );
                          }
                        });
                      },
                      note: _notes[qIndex],
                      onNoteChanged: (note) async {
                        final user = FirebaseAuth.instance.currentUser;
                        final qId = question.id ?? question.number.toString();
                        
                        setState(() {
                          if (note.isEmpty) {
                            _notes.remove(qIndex);
                          } else {
                            _notes[qIndex] = note;
                          }
                        });

                        if (user != null && widget.exam.subjectId.isNotEmpty) {
                          await _srsService.updateNote(
                            user.uid,
                            qId,
                            widget.exam.subjectId,
                            note,
                          );
                        }
                      },
                       onOptionSelected: (id) {
                         setState(() {
                           _currentIndex = qIndex;
                           final currentSet = _selectedAnswers[qIndex] ?? {};
                           
                           if (question.type == QuestionType.checkbox) {
                             // Toggle selection
                             if (currentSet.contains(id)) {
                               currentSet.remove(id);
                             } else {
                               currentSet.add(id);
                             }
                             _selectedAnswers[qIndex] = Set.from(currentSet);
                           } else {
                             // Replace selection
                             _selectedAnswers[qIndex] = {id};
                           }
                           
                           _answerStates[qIndex] = AnswerState.unanswered;
                           _revealed.remove(qIndex);
                         });
                       },
                      isChecked: _revealed.contains(qIndex),
                      isSelected: _selectedAnswers.containsKey(qIndex),
                    ),
                    const _QuestionDivider(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: Icon(
          Icons.arrow_forward_ios_rounded,
          color: isDark ? Colors.white70 : AppColors.textPrimary,
          size: 20,
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.exam.title,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.search_rounded,
              color: AppColors.textSecondary, size: 24),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
      ),
    );
  }
}

/// Divider between questions
class _QuestionDivider extends StatelessWidget {
  const _QuestionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
