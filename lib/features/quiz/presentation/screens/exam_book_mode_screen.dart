import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Answer tracking for filtering
  final Map<int, String?> _selectedOptions = {};
  final Map<int, AnswerState> _answerStates = {};
  final Set<int> _favorites = {}; // Track favorites locally if needed, or via global state

  int get _correctCount => _answerStates.values.where((s) => s == AnswerState.correct).length;
  int get _wrongCount => _answerStates.values.where((s) => s == AnswerState.wrong).length;
  int get _answeredCount => _answerStates.length;

  List<QuizQuestion> get _filteredQuestions {
    return widget.questions.where((q) {
      final index = widget.questions.indexOf(q);
      
      // Tag filter
      if (_selectedTags.isNotEmpty && q.tagLabel != null && !_selectedTags.contains(q.tagLabel)) {
        return false;
      }
      
      // Other filters
      if (_filterFavorites && !_favorites.contains(index)) return false;
      if (_filterCorrected && _answerStates[index] == AnswerState.unanswered) return false;
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
  }

  @override
  void dispose() {
    _timer.cancel();
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

  @override
  Widget build(BuildContext context) {
    // Mock exam data for the header
    final realExam = QuizExam(
      title: widget.config.title,
      classification: widget.config.category ?? 'الدورات الوزارية',
      lastUpdated: widget.config.lastUpdated,
      totalQuestions: widget.questions.length,
      questions: widget.questions,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Search on the left
            Expanded(
              flex: 2,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'بحث في الأسئلة...',
                    hintStyle: GoogleFonts.cairo(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Title on the right
            Text(
              widget.config.title,
              style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Text(
                'إظهار الحل',
                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              Switch(
                value: _showAnswers,
                onChanged: (v) => setState(() => _showAnswers = v),
                activeTrackColor: const Color(0xFF16A34A).withValues(alpha: 0.5),
                activeThumbColor: const Color(0xFF16A34A),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: false,
      ),
      body: Column(
        children: [
          QuizHud(
            current: _answeredCount,
            total: widget.questions.length,
            correctCount: _correctCount,
            wrongCount: _wrongCount,
            elapsed: _stopwatch.elapsed,
            isTimerRunning: _isTimerRunning,
            onToggleTimer: _toggleTimer,
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
                ..._filteredQuestions.map((q) {
                  final index = widget.questions.indexOf(q);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        QuestionCard(
                          question: q,
                          selectedOptionId: _selectedOptions[index],
                          answerState: _answerStates[index] ?? AnswerState.unanswered,
                          showCorrect: _showAnswers,
                          onOptionSelected: (optId) {
                            setState(() {
                              _selectedOptions[index] = optId;
                              final isCorrect = q.correctOptionIds.contains(optId);
                              _answerStates[index] = isCorrect ? AnswerState.correct : AnswerState.wrong;
                            });
                          },
                        ),
                        if (q.explanation != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFF16A34A)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    q.explanation!,
                                    style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF166534)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
}
