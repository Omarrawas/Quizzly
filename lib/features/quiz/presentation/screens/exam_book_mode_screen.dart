import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';

class ExamBookModeScreen extends StatefulWidget {
  final ExamConfig config;
  final List<QuizQuestion> questions;

  const ExamBookModeScreen({
    super.key,
    required this.config,
    required this.questions,
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
  
  // Filtering state
  final Set<String> _selectedTags = {};
  bool _filterFavorites = false;
  bool _filterImportant = false;
  bool _filterCorrected = false;
  bool _filterWrong = false;
  bool _filterCorrect = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isFabExpanded = false;
  bool _filterCorrectOnly = false;
  bool _filterWrongOnly = false;

  // State tracking
  final Map<int, String?> _selectedOptions = {};
  final Map<int, AnswerState> _answerStates = {};
  final Set<int> _favorites = {};
  final Set<int> _checkedQuestions = {};
  final Map<int, String> _notes = {};

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
      if (_filterFavorites && !_favorites.contains(index)) return false;
      if (_filterCorrected && !_checkedQuestions.contains(index)) return false;
      if (_filterWrong && _answerStates[index] != AnswerState.wrong) return false;
      if (_filterCorrect && _answerStates[index] != AnswerState.correct) return false;
      
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

  void _onOptionSelected(int questionIndex, String optionId) {
    setState(() {
      _selectedOptions[questionIndex] = optionId;
    });
    _saveState();
  }

  void _onCheckAnswer(int questionIndex) {
    if (_selectedOptions[questionIndex] == null) return;
    
    setState(() {
      _checkedQuestions.add(questionIndex);
      
      final question = widget.questions[questionIndex];
      final selectedId = _selectedOptions[questionIndex];
      
      if (question.correctOptionIds.contains(selectedId)) {
        _answerStates[questionIndex] = AnswerState.correct;
      } else {
        _answerStates[questionIndex] = AnswerState.wrong;
      }
    });
    _saveState();
  }

  void _toggleFavorite(int questionIndex) {
    setState(() {
      if (_favorites.contains(questionIndex)) {
        _favorites.remove(questionIndex);
      } else {
        _favorites.add(questionIndex);
      }
    });
    _saveState();
  }

  void _addNote(int questionIndex, String note) {
    setState(() {
      if (note.trim().isEmpty) {
        _notes.remove(questionIndex);
      } else {
        _notes[questionIndex] = note;
      }
    });
    _saveState();
  }

  String get _storageKey => 'quiz_state_${widget.config.title}';

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'selectedOptions': _selectedOptions.map((k, v) => MapEntry(k.toString(), v)),
      'answerStates': _answerStates.map((k, v) => MapEntry(k.toString(), v.name)),
      'favorites': _favorites.toList(),
      'checkedQuestions': _checkedQuestions.toList(),
      'notes': _notes.map((k, v) => MapEntry(k.toString(), v)),
      'elapsedMs': _stopwatch.elapsedMilliseconds + _elapsedOffset.inMilliseconds,
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
            _selectedOptions[int.parse(k)] = v;
          });
        }
        if (state['answerStates'] != null) {
          (state['answerStates'] as Map).forEach((k, v) {
            _answerStates[int.parse(k)] = AnswerState.values.byName(v);
          });
        }
        if (state['favorites'] != null) {
          _favorites.addAll((state['favorites'] as List).cast<int>());
        }
        if (state['checkedQuestions'] != null) {
          _checkedQuestions.addAll((state['checkedQuestions'] as List).cast<int>());
        }
        if (state['notes'] != null) {
          (state['notes'] as Map).forEach((k, v) {
            _notes[int.parse(k)] = v;
          });
        }
        if (state['elapsedMs'] != null) {
          _elapsedOffset = Duration(milliseconds: state['elapsedMs'] as int);
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
        if (_selectedOptions[i] != null) {
          _checkedQuestions.add(i);
          final question = widget.questions[i];
          final selectedId = _selectedOptions[i];
          if (question.correctOptionIds.contains(selectedId)) {
            _answerStates[i] = AnswerState.correct;
          } else {
            _answerStates[i] = AnswerState.wrong;
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
    // In this context, it's similar to checkAll but maybe just for the currently visible ones?
    // Or maybe checkAll means reveal all answers even if not selected?
    // Let's make Check All reveal all answers (like the toggle).
    setState(() {
      _showAnswers = true;
      _isFabExpanded = false;
    });
    _saveState();
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

    return Scaffold(
      floatingActionButton: _buildExpandableFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Back Button (Far Right in RTL)
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            // Title
            Text(
              widget.config.title,
              style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const Spacer(),
            // Show Solution Toggle
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الحل',
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
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
            // Search Bar (Far Left in RTL)
            Expanded(
              flex: 2,
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'بحث...',
                    hintStyle: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
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
            additionalAction: InkWell(
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
                      _showFilters ? 'إخفاء الفلاتر' : 'إظهار الفلاتر',
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
            ),
          ),
          if (_showFilters) _buildFilterPanel(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                QuizExamHeader(exam: realExam),
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
                      isSelected: _selectedOptions[realIndex] != null,
                      selectedOptionId: _selectedOptions[realIndex],
                      answerState: _answerStates[realIndex] ?? AnswerState.unanswered,
                      showCorrect: _showAnswers || _checkedQuestions.contains(realIndex),
                      onOptionSelected: (optId) => _onOptionSelected(realIndex, optId),
                      isFavorite: _favorites.contains(realIndex),
                      onFavoriteToggle: () => _toggleFavorite(realIndex),
                      note: _notes[realIndex],
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
                            title: '${widget.config.title} - $tag',
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

  Widget _buildFilterPanel() {
    final tagCounts = _tagCounts;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'الفلاتر',
              style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'الوسوم',
              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
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
                        color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? const Color(0xFFD8B4FE) : AppColors.borderLight),
                      ),
                      child: Text(
                        '${entry.key} (${entry.value})',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: isSelected ? const Color(0xFF7E22CE) : AppColors.textPrimary,
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
                    Expanded(child: _buildCheckbox('المفضلة', _filterFavorites, (v) => setState(() => _filterFavorites = v))),
                    Expanded(child: _buildCheckbox('مهم', _filterImportant, (v) => setState(() => _filterImportant = v))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildCheckbox('الأسئلة المصححة', _filterCorrected, (v) => setState(() => _filterCorrected = v))),
                    Expanded(child: _buildCheckbox('الإجابات الخاطئة', _filterWrong, (v) => setState(() => _filterWrong = v))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildCheckbox('الإجابات الصحيحة', _filterCorrect, (v) => setState(() => _filterCorrect = v))),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool> onChanged) {
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
              border: Border.all(color: value ? AppColors.primaryBlue : AppColors.borderLight, width: 2),
              color: value ? AppColors.primaryBlue : Colors.transparent,
            ),
            child: value ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: value ? AppColors.primaryBlue : AppColors.textPrimary,
              fontWeight: value ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
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
}
