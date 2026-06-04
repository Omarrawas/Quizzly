import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';
import 'package:quizzly/features/quiz/domain/services/list_service.dart';
import 'package:quizzly/features/quiz/domain/services/spaced_repetition_service.dart';
import 'package:quizzly/features/admin/domain/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExamBookModeScreen extends StatefulWidget {
  final ExamConfig config;
  final List<QuizQuestion> questions;
  final bool isSubExam;
  final bool isGlobalSearch;

  const ExamBookModeScreen({
    super.key,
    required this.config,
    required this.questions,
    this.isSubExam = false,
    this.isGlobalSearch = false,
  });

  @override
  State<ExamBookModeScreen> createState() => _ExamBookModeScreenState();
}

class _ExamBookModeScreenState extends State<ExamBookModeScreen> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  Duration _elapsedOffset = Duration.zero;
  bool _isTimerRunning = false;
  bool _showAnswers = false;
  bool _showFilters = false;
  bool _isSearchingMobile = false;
  
  // Filtering state
  final Set<String> _selectedTags = {};
  bool _filterFavorites = false;
  bool _filterImportant = false;
  bool _filterCorrected = false;
  bool _filterWrong = false;
  bool _filterCorrect = false;
  String _filterPaperType = 'all'; // 'all', 'exam', 'bank'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isFabExpanded = false;
  bool _filterCorrectOnly = false;
  bool _filterWrongOnly = false;

  // State tracking
  final Map<int, Set<String>> _selectedOptions = {};
  final Map<int, AnswerState> _answerStates = {};
  final Set<String> _favoriteIds = {};
  final Set<String> _importantIds = {};
  final Set<int> _checkedQuestions = {};
  final Map<String, String> _notesByQuestionId = {}; // QuestionID -> Note

  final _listService = ListService();
  final _srsService = SpacedRepetitionService();
  StreamSubscription? _favoriteSubscription;
  StreamSubscription? _importantSubscription;
  
  String _primaryListId = 'favorites';
  List<UserList> _userLists = [];
  final Set<String> _primaryListIds = {};
  StreamSubscription? _userListsSubscription;
  StreamSubscription? _primaryListIdSubscription;
  StreamSubscription? _primaryListSyncSubscription;

  int get _correctCount => _answerStates.values.where((s) => s == AnswerState.correct).length;
  int get _wrongCount => _answerStates.values.where((s) => s == AnswerState.wrong).length;
  int get _answeredCount => _checkedQuestions.length;

  List<QuizQuestion> get _filteredQuestions {
    return widget.questions.where((q) {
      final index = widget.questions.indexOf(q);
      
      // Tag filter
      if (_selectedTags.isNotEmpty && q.tagLabel != null && !_selectedTags.contains(q.tagLabel)) {
        return false;
      }
      
      // Status pill filters (Toggle functionality)
      if (_filterCorrectOnly && _answerStates[index] != AnswerState.correct) return false;
      if (_filterWrongOnly && _answerStates[index] != AnswerState.wrong) return false;

      // Checkbox filters from bottom sheet
      if (_filterFavorites && (q.id == null || !_favoriteIds.contains(q.id))) return false;
      if (_filterCorrected && !_checkedQuestions.contains(index)) return false;
      if (_filterWrong && _answerStates[index] != AnswerState.wrong) return false;
      if (_filterCorrect && _answerStates[index] != AnswerState.correct) return false;
      
      // Paper type filter
      if (_filterPaperType == 'exam' && q.examTags.isEmpty) return false;
      if (_filterPaperType == 'bank' && q.examTags.isNotEmpty) return false;
      
      // Search filter
      if (_searchQuery.isNotEmpty && !q.text.contains(_searchQuery)) {
        return false;
      }
      
      return true;
    }).toList();
  }

  Map<String, int> get _tagCounts {
    final counts = <String, int>{};
    for (var q in widget.questions) {
      if (q.tagLabel != null) {
        counts[q.tagLabel!] = (counts[q.tagLabel!] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isTimerRunning) setState(() {});
    });
    _loadState();
    _setupFavoritesSync();
    _setupImportantSync();
    _userListsSubscription = _listService.streamLists().listen((lists) {
      if (mounted) setState(() => _userLists = lists);
    });
    _primaryListIdSubscription = _listService.streamPrimaryListId().listen((listId) {
      if (mounted) {
        setState(() => _primaryListId = listId);
        _setupPrimaryListSync(listId);
      }
    });
    _setupPrimaryListSync('favorites'); // Fallback until stream emits
    _loadCloudNotes();
  }

  Future<void> _loadCloudNotes() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || widget.config.subjectId.isEmpty) return;

    try {
      final subjectData = await _srsService.getAllSubjectData(userId, widget.config.subjectId);
      if (mounted) {
        setState(() {
          // Merge both mnemonics and notes into the local notes map
          final mergedNotes = subjectData.map((key, value) {
            final note = value['note'] ?? value['mnemonic'] ?? '';
            return MapEntry(key, note);
          });
          _notesByQuestionId.addAll(mergedNotes);
        });
      }
    } catch (e) {
      debugPrint('Error loading cloud notes: $e');
    }
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

  void _setupFavoritesSync() {
    _favoriteSubscription = _listService.streamListQuestionIds('favorites').listen((ids) {
      if (mounted) {
        setState(() {
          _favoriteIds.clear();
          _favoriteIds.addAll(ids);
        });
      }
    });
  }

  void _setupImportantSync() {
    _importantSubscription = _listService.streamListQuestionIds('important').listen((ids) {
      if (mounted) {
        setState(() {
          _importantIds.clear();
          _importantIds.addAll(ids);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _favoriteSubscription?.cancel();
    _importantSubscription?.cancel();
    _primaryListSyncSubscription?.cancel();
    _userListsSubscription?.cancel();
    _primaryListIdSubscription?.cancel();
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

  void _onOptionSelected(int questionIndex, String optionId, QuestionType type) {
    setState(() {
      final currentSet = _selectedOptions[questionIndex] ?? {};
      
      if (type == QuestionType.checkbox) {
        if (currentSet.contains(optionId)) {
          currentSet.remove(optionId);
        } else {
          currentSet.add(optionId);
        }
        _selectedOptions[questionIndex] = Set.from(currentSet);
      } else {
        _selectedOptions[questionIndex] = {optionId};
      }
    });
    _saveState();
  }

  void _onCheckAnswer(int questionIndex) {
    final sel = _selectedOptions[questionIndex] ?? {};
    if (sel.isEmpty) return;
    
    setState(() {
      _checkedQuestions.add(questionIndex);
      
      final question = widget.questions[questionIndex];
      
      bool isCorrect = false;
      if (question.type == QuestionType.checkbox) {
        isCorrect = sel.length == question.correctOptionIds.length &&
            sel.every((id) => question.correctOptionIds.contains(id));
      } else {
        isCorrect = sel.length == 1 &&
            question.correctOptionIds.contains(sel.first);
      }
      
      if (isCorrect) {
        _answerStates[questionIndex] = AnswerState.correct;
        // Remove from wrong answers if it was corrected
        if (widget.config.subjectId.isNotEmpty) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            final dbService = DatabaseService();
            final qId = question.id ?? question.number.toString();
            dbService.updateUserHistoryForSubject(
              userId,
              removeWrongIds: [qId],
              subjectId: widget.config.subjectId,
            );
          }
        }
      } else {
        _answerStates[questionIndex] = AnswerState.wrong;
        // Add to wrong answers
        if (widget.config.subjectId.isNotEmpty) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            final dbService = DatabaseService();
            final qId = question.id ?? question.number.toString();
            dbService.updateUserHistoryForSubject(
              userId,
              addWrongIds: [qId],
              subjectId: widget.config.subjectId,
            );
          }
        }
      }
    });
    _saveState();
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

  void _addNote(int questionIndex, String note) {
    final question = widget.questions[questionIndex];
    final qId = question.id;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (qId != null) {
      setState(() {
        if (note.trim().isEmpty) {
          _notesByQuestionId.remove(qId);
        } else {
          _notesByQuestionId[qId] = note;
        }
      });

      if (userId != null && widget.config.subjectId.isNotEmpty) {
        _srsService.updateNote(userId, qId, widget.config.subjectId, note);
      }
    }
    _saveState();
  }

  String get _storageKey => 'quiz_state_${widget.config.title}';

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'selectedOptions': _selectedOptions.map((k, v) => MapEntry(k.toString(), v.toList())),
      'answerStates': _answerStates.map((k, v) => MapEntry(k.toString(), v.name)),
      'favorites': _favoriteIds.toList(),
      'checkedQuestions': _checkedQuestions.toList(),
      'elapsedMs': _stopwatch.elapsedMilliseconds + _elapsedOffset.inMilliseconds,
      'notes': _notesByQuestionId,
    };
    await prefs.setString(_storageKey, jsonEncode(state));
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null) {
      final state = jsonDecode(saved) as Map<String, dynamic>;
      setState(() {
        if (state['selectedOptions'] != null) {
          (state['selectedOptions'] as Map).forEach((k, v) {
            if (v is List) {
              _selectedOptions[int.parse(k)] = Set<String>.from(v.cast<String>());
            } else if (v is String) {
              _selectedOptions[int.parse(k)] = {v};
            }
          });
        }
        if (state['answerStates'] != null) {
          (state['answerStates'] as Map).forEach((k, v) {
            _answerStates[int.parse(k)] = AnswerState.values.byName(v);
          });
        }
        if (state['favorites'] != null) {
          _favoriteIds.addAll((state['favorites'] as List).cast<String>());
        }
        if (state['checkedQuestions'] != null) {
          _checkedQuestions.addAll((state['checkedQuestions'] as List).cast<int>());
        }
        if (state['elapsedMs'] != null) {
          _elapsedOffset = Duration(milliseconds: state['elapsedMs'] as int);
        }
        if (state['notes'] != null) {
          (state['notes'] as Map).forEach((k, v) {
            _notesByQuestionId[k.toString()] = v.toString();
          });
        }
      });
    }
  }

  Future<void> _resetAnswers() async {
    setState(() {
      _selectedOptions.clear();
      _answerStates.clear();
      _checkedQuestions.clear();
      _showAnswers = false;
      _isFabExpanded = false;
      _elapsedOffset = Duration.zero;
      _stopwatch.reset();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تصفير كافة الإجابات', textAlign: TextAlign.right)),
    );
  }

  void _checkAll() {
    setState(() {
      for (int i = 0; i < widget.questions.length; i++) {
          final question = widget.questions[i];
          final sel = _selectedOptions[i] ?? {};
          
          bool isCorrect = false;
          if (question.type == QuestionType.checkbox) {
            isCorrect = sel.length == question.correctOptionIds.length &&
                sel.every((id) => question.correctOptionIds.contains(id));
          } else {
            isCorrect = sel.length == 1 &&
                question.correctOptionIds.contains(sel.first);
          }
          
          if (isCorrect) {
            _answerStates[i] = AnswerState.correct;
          } else {
            _answerStates[i] = AnswerState.wrong;
          }
      }
      _isFabExpanded = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تصحيح كافة الأسئلة المجابة', textAlign: TextAlign.right)),
    );
  }

  void _checkMyAnswers() {
    // In this context, it's similar to checkAll but maybe just for the currently visible ones?
    // Or maybe checkAll means reveal all answers even if not selected?
    // Let's make Check All reveal all answers (like the toggle).
    setState(() {
      _showAnswers = true;
      _isFabExpanded = false;
    });
    _saveState();
  }

  bool get _isSearchEmptyState {
    return widget.isGlobalSearch &&
        _searchQuery.isEmpty &&
        _selectedTags.isEmpty &&
        _filterPaperType == 'all' &&
        !_filterCorrectOnly &&
        !_filterWrongOnly &&
        !_filterFavorites &&
        !_filterImportant &&
        !_filterCorrected &&
        !_filterWrong &&
        !_filterCorrect;
  }

  Widget _buildEmptySearchState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.search_rounded, size: 80, color: isDark ? Colors.white10 : const Color(0xFF1E3A8A)),
          const SizedBox(height: 24),
          Text(
            'ابدأ البحث',
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
              'استخدم الفلاتر أعلاه للبحث عن الأسئلة. يمكنك البحث بالوسوم، نوع الورقة، أو خصائص أخرى',
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
    );
  }

  Widget _buildFilterButton(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _showFilters = !_showFilters),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _showFilters 
              ? AppColors.primaryBlue.withValues(alpha: 0.1) 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _showFilters 
                ? AppColors.primaryBlue 
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
                color: _showFilters ? AppColors.primaryBlue : (isDark ? Colors.white38 : AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: _showFilters ? AppColors.primaryBlue : (isDark ? Colors.white38 : AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mock exam data for the header
    final realExam = QuizExam(
      title: widget.config.title,
      classification: widget.config.category ?? 'الدورات الوزارية',
      type: widget.config.type,
      lastUpdated: widget.config.lastUpdated,
      createdAt: widget.config.createdAt,
      totalQuestions: widget.questions.length,
      questions: widget.questions,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 600;

    return Scaffold(
      floatingActionButton: _buildExpandableFab(isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            if (isSmallScreen && _isSearchingMobile) ...[
              // Cancel Search Button on Mobile
              IconButton(
                icon: Icon(Icons.arrow_forward_ios, size: 18, color: isDark ? Colors.white : Colors.black),
                onPressed: () {
                  setState(() {
                    _isSearchingMobile = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
              const SizedBox(width: 8),
              // Search Input occupying full remaining width on Mobile
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    textAlign: TextAlign.right,
                    autofocus: true,
                    style: GoogleFonts.cairo(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'بحث...',
                      hintStyle: GoogleFonts.cairo(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
                      prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.white38 : Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Back Button (Far Right in RTL)
              if (widget.isSubExam && !widget.isGlobalSearch)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white : Colors.black),
                  label: Text(
                    'العودة للدورة', 
                    style: GoogleFonts.cairo(
                      fontSize: 12, 
                      color: isDark ? Colors.white : Colors.black, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, size: 18, color: isDark ? Colors.white : Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              const SizedBox(width: 8),
              // Title
              Expanded(
                child: Text(
                  widget.config.title,
                  style: GoogleFonts.cairo(
                    fontSize: 15, 
                    fontWeight: FontWeight.bold, 
                    color: isDark ? Colors.white : AppColors.textPrimary
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              // Show Solution Toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الحل',
                    style: GoogleFonts.cairo(
                      fontSize: 11, 
                      fontWeight: FontWeight.bold, 
                      color: isDark ? Colors.white38 : AppColors.textSecondary
                    ),
                  ),
                  Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: _showAnswers,
                      onChanged: (v) => setState(() => _showAnswers = v),
                      activeTrackColor: const Color(0xFF16A34A).withValues(alpha: 0.3),
                      activeThumbColor: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              if (isSmallScreen) ...[
                // Search Toggle Icon for Mobile
                IconButton(
                  icon: Icon(Icons.search, color: isDark ? Colors.white : Colors.black),
                  onPressed: () => setState(() => _isSearchingMobile = true),
                ),
              ] else ...[
                // Standard Search Bar for Desktop/Tablet (Far Left in RTL)
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.cairo(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'بحث...',
                        hintStyle: GoogleFonts.cairo(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
                        prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.white38 : Colors.grey),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          QuizHud(
            current: _answeredCount,
            total: widget.questions.length,
            correctCount: _correctCount,
            wrongCount: _wrongCount,
            elapsed: _stopwatch.elapsed + _elapsedOffset,
            isTimerRunning: _isTimerRunning,
            onToggleTimer: _toggleTimer,
            onCorrectTap: () {
              setState(() {
                _filterCorrectOnly = !_filterCorrectOnly;
                _filterWrongOnly = false;
              });
            },
            onWrongTap: () {
              setState(() {
                _filterWrongOnly = !_filterWrongOnly;
                _filterCorrectOnly = false;
              });
            },
            additionalAction: widget.isGlobalSearch ? null : _buildFilterButton(isDark),
          ),
          if (widget.isGlobalSearch)
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
                  _buildFilterButton(isDark),
                  Row(
                    children: [
                      Text(
                        '${widget.questions.length} سؤال',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[300] : const Color(0xFF1E3A8A), // Dark blue
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.description_outlined, 
                        color: isDark ? Colors.blue[300] : const Color(0xFF1E3A8A), 
                        size: 18
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_showFilters) _buildFilterPanel(isDark),
          Expanded(
            child: _isSearchEmptyState
                ? _buildEmptySearchState(isDark)
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (!widget.isGlobalSearch) QuizExamHeader(exam: realExam),
                      const SizedBox(height: 8),
                      ..._filteredQuestions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final q = entry.value;
                  final realIndex = widget.questions.indexOf(q);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: QuestionCard(
                      question: q,
                      displayIndex: index + 1,
                      isSelected: _selectedOptions.containsKey(realIndex),
                      selectedOptionIds: _selectedOptions[realIndex] ?? {},
                      answerState: _answerStates[realIndex] ?? AnswerState.unanswered,
                      showCorrect: _showAnswers || _checkedQuestions.contains(realIndex),
                      onOptionSelected: (optId) => _onOptionSelected(realIndex, optId, q.type),
                      isInPrimaryList: q.id != null && _primaryListIds.contains(q.id),
                      onListToggle: () {
                        if (q.id != null) {
                          _listService.toggleQuestionInList(_primaryListId, q);
                        }
                      },
                      onListLongPress: () => _showListSelectionDialog(),
                      listIcon: _getPrimaryListIcon(q.id != null && _primaryListIds.contains(q.id)),
                      listColor: _getPrimaryListColor(),
                      note: q.id != null ? _notesByQuestionId[q.id] : null,
                      onNoteChanged: (note) => _addNote(realIndex, note),
                      onCheckAnswer: () => _onCheckAnswer(realIndex),
                      isChecked: _checkedQuestions.contains(realIndex),
                      onTagTap: (tag) {
                        final filteredQuestions = widget.questions.where((q) {
                          return q.topicNames?.contains(tag) ?? false;
                        }).toList();

                        if (filteredQuestions.isNotEmpty) {
                          final newConfig = ExamConfig(
                            id: '${widget.config.id}_$tag',
                            title: tag,
                            type: widget.config.type,
                            durationSeconds: widget.config.durationSeconds,
                            totalQuestions: filteredQuestions.length,
                            passingScore: widget.config.passingScore,
                            subjectId: widget.config.subjectId,
                            sectionId: widget.config.sectionId,
                            category: widget.config.category,
                            staticQuestionIds: filteredQuestions.map((q) => q.id ?? '').toList(),
                            generationRules: widget.config.generationRules,
                            isFree: widget.config.isFree,
                            lastUpdated: widget.config.lastUpdated,
                            createdAt: widget.config.createdAt,
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExamBookModeScreen(
                                config: newConfig,
                                questions: filteredQuestions,
                                isSubExam: true,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(bool isDark) {
    final tagCounts = _tagCounts;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'الفلاتر',
              style: GoogleFonts.cairo(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white : AppColors.textPrimary
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'الوسوم',
              style: GoogleFonts.cairo(
                fontSize: 14, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white38 : AppColors.textSecondary
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: tagCounts.entries.map((entry) {
                final isSelected = _selectedTags.contains(entry.key);
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTags.remove(entry.key);
                        } else {
                          _selectedTags.add(entry.key);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFFF3E8FF).withValues(alpha: isDark ? 0.2 : 1.0) 
                            : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFFD8B4FE) 
                              : (isDark ? Colors.white10 : AppColors.borderLight)
                        ),
                      ),
                      child: Text(
                        '${entry.key} (${entry.value})',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: isSelected 
                              ? (isDark ? Colors.purple[200] : const Color(0xFF7E22CE)) 
                              : (isDark ? Colors.white70 : AppColors.textPrimary),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildCheckbox('المفضلة', _filterFavorites, (v) => setState(() => _filterFavorites = v), isDark)),
                    Expanded(child: _buildCheckbox('مهم', _filterImportant, (v) => setState(() => _filterImportant = v), isDark)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildCheckbox('الأسئلة المصححة', _filterCorrected, (v) => setState(() => _filterCorrected = v), isDark)),
                    Expanded(child: _buildCheckbox('الإجابات الخاطئة', _filterWrong, (v) => setState(() => _filterWrong = v), isDark)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildCheckbox('الإجابات الصحيحة', _filterCorrect, (v) => setState(() => _filterCorrect = v), isDark)),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                if (widget.isGlobalSearch) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: isDark ? Colors.white10 : AppColors.borderLight),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'نوع الورقة',
                      style: GoogleFonts.cairo(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.white38 : AppColors.textSecondary
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPaperTypeButton('الكل', 'all', Icons.check_rounded, isDark),
                      const SizedBox(width: 8),
                      _buildPaperTypeButton('امتحانات', 'exam', Icons.description_outlined, isDark),
                      const SizedBox(width: 8),
                      _buildPaperTypeButton('بنك الأسئلة', 'bank', Icons.account_balance_outlined, isDark),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperTypeButton(String label, String value, IconData icon, bool isDark) {
    final isSelected = _filterPaperType == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filterPaperType = value),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white10 : AppColors.borderLight),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : (isDark ? Colors.white38 : AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool> onChanged, bool isDark) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppColors.primaryBlue : (isDark ? Colors.white10 : AppColors.borderLight), 
                width: 2
              ),
              color: value ? AppColors.primaryBlue : Colors.transparent,
            ),
            child: value ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: value ? AppColors.primaryBlue : (isDark ? Colors.white70 : AppColors.textPrimary),
              fontWeight: value ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
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
            _isFabExpanded ? Icons.close : Icons.more_vert,
            color: AppColors.primaryBlue,
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
            child: Icon(icon, color: AppColors.primaryBlue, size: 22),
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
}
