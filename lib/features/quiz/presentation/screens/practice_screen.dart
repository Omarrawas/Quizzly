import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/practice_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/practice_session_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/practice_history_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Practice Setup Screen — Topic Selector + Mode Config
// ─────────────────────────────────────────────────────────────────────────────
class PracticeScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const PracticeScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> with SingleTickerProviderStateMixin {
  final PracticeService _service = PracticeService();

  List<Map<String, dynamic>> _topics = [];
  final Set<String> _selectedTopicIds = {};
  Difficulty? _selectedDifficulty; // null = all
  bool _loading = true;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _loadTopics();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      final topics = await _service.getTopicsForSubject(widget.subjectId);
      
      if (mounted) {
        final chapters = <String, String>{};
        for (var t in topics) {
          if (t['type'] == 'chapter') {
            chapters[t['id']] = t['name'] as String;
          }
        }

        final compositeTopics = <Map<String, dynamic>>[];
        for (var t in topics) {
          if (t['type'] == 'lesson' || t['parentId'] != null) {
            final parentId = t['parentId'] as String?;
            final parentName = parentId != null ? chapters[parentId] : null;
            final currentName = t['name'] as String;
            final compositeName = parentName != null ? '$parentName - $currentName' : currentName;
            
            // Create a modified copy of the topic
            final modifiedTopic = Map<String, dynamic>.from(t);
            modifiedTopic['name'] = compositeName;
            compositeTopics.add(modifiedTopic);
          } else if (t['type'] != 'chapter') {
            compositeTopics.add(t);
          }
        }

        setState(() {
          _topics = compositeTopics;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleTopic(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedTopicIds.contains(id)) {
        _selectedTopicIds.remove(id);
      } else {
        _selectedTopicIds.add(id);
      }
    });
  }

  Future<void> _startPractice() async {
    HapticFeedback.mediumImpact();

    final topicIds = _selectedTopicIds.isEmpty ? null : _selectedTopicIds.toList();
    final topicNames = _selectedTopicIds.isEmpty
        ? ['جميع المواضيع']
        : _topics
            .where((t) => _selectedTopicIds.contains(t['id']))
            .map((t) => t['name'] as String)
            .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeSessionScreen(
          subjectId: widget.subjectId,
          topicIds: topicIds,
          topicNames: topicNames,
          selectedDifficulty: _selectedDifficulty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar ──────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeHistoryScreen(
                      subjectId: widget.subjectId,
                      subjectName: widget.subjectName,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'وضع التدريب',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  widget.subjectName,
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body Content ────────────────────────────────
          SliverToBoxAdapter(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : FadeTransition(
                    opacity: _animController,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info card
                          _buildInfoCard(isDark),
                          const SizedBox(height: 24),

                          // Difficulty filter
                          _buildSectionTitle('الصعوبة', Icons.tune_rounded),
                          const SizedBox(height: 12),
                          _buildDifficultySelector(),
                          const SizedBox(height: 24),

                          // Topics selector
                          _buildSectionTitle(
                            _selectedTopicIds.isEmpty
                                ? 'اختر المواضيع (أو اتركه فارغاً للكل)'
                                : 'المواضيع المختارة (${_selectedTopicIds.length})',
                            Icons.topic_rounded,
                          ),
                          const SizedBox(height: 12),
                          _topics.isEmpty
                              ? _buildEmptyTopics(isDark)
                              : _buildTopicsList(isDark),
                          const SizedBox(height: 100), // Space for FAB
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : _buildStartButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.1),
            const Color(0xFF7C3AED).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _buildInfoChip(Icons.access_time_rounded, 'بدون توقيت'),
          const SizedBox(width: 12),
          _buildInfoChip(Icons.lightbulb_outline_rounded, 'إجابة فورية'),
          const SizedBox(width: 12),
          _buildInfoChip(Icons.description_outlined, 'مع الشرح'),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 20),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 18),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildDifficultySelector() {
    final List<Map<String, dynamic>> options = [
      {'label': 'الكل', 'value': null, 'color': const Color(0xFF64748B), 'icon': Icons.all_inclusive_rounded},
      {'label': 'سهل', 'value': Difficulty.easy, 'color': const Color(0xFF16A34A), 'icon': Icons.signal_cellular_alt_1_bar_rounded},
      {'label': 'متوسط', 'value': Difficulty.medium, 'color': const Color(0xFFD97706), 'icon': Icons.signal_cellular_alt_2_bar_rounded},
      {'label': 'صعب', 'value': Difficulty.hard, 'color': const Color(0xFFDC2626), 'icon': Icons.signal_cellular_alt_rounded},
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = _selectedDifficulty == opt['value'];
        final color = opt['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDifficulty = opt['value'] as Difficulty?);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? color : AppColors.borderLight),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(opt['icon'] as IconData, color: isSelected ? Colors.white : color, size: 18),
                  const SizedBox(height: 4),
                  Text(
                    opt['label'] as String,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopicsList(bool isDark) {
    return Column(
      children: _topics.map((topic) {
        final id = topic['id'] as String;
        final name = topic['name'] as String? ?? '';
        final isSelected = _selectedTopicIds.contains(id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => _toggleTopic(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBlue.withValues(alpha: 0.08)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primaryBlue : (isDark ? Colors.white12 : AppColors.borderLight),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyTopics(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.topic_outlined, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('لا توجد مواضيع بعد', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
          Text('سيتم تحميل جميع أسئلة المادة', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _startPractice,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 22),
              const SizedBox(width: 8),
              Text(
                _selectedTopicIds.isEmpty ? 'ابدأ التدريب (جميع المواضيع)' : 'ابدأ التدريب (${_selectedTopicIds.length} مواضيع)',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
