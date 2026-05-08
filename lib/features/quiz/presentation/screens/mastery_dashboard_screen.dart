import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/subject/domain/services/subject_stats_service.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/cram_mode_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/cram_mode_session_screen.dart';

class MasteryDashboardScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const MasteryDashboardScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<MasteryDashboardScreen> createState() => _MasteryDashboardScreenState();
}

class _MasteryDashboardScreenState extends State<MasteryDashboardScreen> {
  final SubjectStatsService _statsService = SubjectStatsService();
  final CramModeService _cramModeService = CramModeService();
  String _activeFilter = 'all'; // all, mistakes, favorites, struggling

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthService>().user?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'مركز الإتقان',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSummaryHeader(userId)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              activeFilter: _activeFilter,
              onFilterChanged: (filter) => setState(() => _activeFilter = filter),
            ),
          ),
          _buildQuestionsList(userId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startPracticeSession(userId),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
        label: Text(
          'بدء جلسة مراجعة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }


  Widget _buildSummaryHeader(String userId) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          _buildSummaryCard(
            'أخطاء',
            _statsService.streamWrongAnswersCount(userId, widget.subjectId),
            const Color(0xFFDC2626),
            Icons.error_outline_rounded,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'مفضلة',
            _statsService.streamFavoritesCount(userId, widget.subjectId),
            const Color(0xFFEA580C),
            Icons.favorite_border_rounded,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'SRS',
            _statsService.streamDueQuestionsCount(userId, widget.subjectId),
            const Color(0xFF2563EB),
            Icons.history_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, Stream<int> stream, Color color, IconData icon) {
    return Expanded(
      child: StreamBuilder<int>(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionsList(String userId) {
    // Stream questions based on active filter
    Stream<List<QuizQuestion>> questionsStream;
    if (_activeFilter == 'favorites') {
      questionsStream = _statsService.streamFavoriteQuestions(userId, widget.subjectId);
    } else if (_activeFilter == 'mistakes') {
      questionsStream = _statsService.streamWrongQuestions(userId, widget.subjectId);
    } else {
      // Default: Show all problems (favorites + mistakes + struggling)
      questionsStream = _statsService.streamAllProblematicQuestions(userId, widget.subjectId);
    }

    return StreamBuilder<List<QuizQuestion>>(
      stream: questionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
          );
        }

        final questions = snapshot.data ?? [];
        if (questions.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _activeFilter == 'favorites' ? Icons.star_outline_rounded : Icons.check_circle_outline_rounded,
                    color: Colors.grey[300],
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _activeFilter == 'favorites' ? 'لا توجد أسئلة مفضلة' : 'كل شيء تحت السيطرة!',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    _activeFilter == 'favorites' ? 'أضف أسئلة للمفضلة لتجدها هنا' : 'لا توجد أسئلة في هذا التصنيف حالياً',
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildQuestionItem(questions[index]),
              childCount: questions.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionItem(QuizQuestion question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  question.tagLabel ?? 'سؤال',
                  style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey[700]),
                ),
              ),
              const Spacer(),
              _buildActionButton(Icons.archive_outlined, 'أرشفة', Colors.blue, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم تفعيل ميزة الأرشفة قريباً')),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: const Color(0xFF0F172A),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // We'll use the active filter or some logic to show tags
              // For now, if we are in mistakes tab, show mistake tag, etc.
              if (_activeFilter == 'mistakes' || _activeFilter == 'all')
                _buildTag(Icons.history_rounded, 'إجابة خاطئة', Colors.red),
              if ((_activeFilter == 'favorites' || _activeFilter == 'all') && (_activeFilter != 'mistakes'))
                Padding(
                  padding: EdgeInsets.only(right: _activeFilter == 'all' ? 8 : 0),
                  child: _buildTag(Icons.star_rounded, 'مفضل', Colors.amber),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 12, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _startPracticeSession(String userId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blue)),
    );

    try {
      final questions = await _cramModeService.generateCramSession(userId, widget.subjectId);
      if (!mounted) return;
      Navigator.pop(context);

      if (questions.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CramModeSessionScreen(
            questions: questions,
            subjectId: widget.subjectId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }
}

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final String activeFilter;
  final Function(String) onFilterChanged;

  _FilterBarDelegate({required this.activeFilter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _buildFilterChip('الكل', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('الأخطاء', 'mistakes'),
          const SizedBox(width: 8),
          _buildFilterChip('المفضلة', 'favorites'),
          const SizedBox(width: 8),
          _buildFilterChip('قيد التعلم', 'struggling'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isActive = activeFilter == value;
    return GestureDetector(
      onTap: () => onFilterChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF0F172A) : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 70;
  @override
  double get minExtent => 70;
  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) {
    return oldDelegate.activeFilter != activeFilter;
  }
}
