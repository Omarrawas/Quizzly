import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/presentation/widgets/hub_action_card.dart';
import 'package:quizzly/features/quiz/presentation/screens/wrong_answers_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/practice_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/lists_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/performance_screen.dart';
import 'package:quizzly/features/gamification/domain/services/gamification_service.dart';
import 'package:quizzly/features/gamification/data/models/gamification_profile.dart';
import 'package:quizzly/features/subject/domain/services/subject_stats_service.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/subject/presentation/widgets/smart_coach_banner.dart';
import 'package:quizzly/features/quiz/domain/services/spaced_repetition_service.dart';
import 'package:quizzly/features/quiz/domain/services/exam_generator_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/active_recall_session_screen.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/subject/presentation/screens/subject_tags_screen.dart';

class SubjectHubScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const SubjectHubScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SubjectHubScreen> createState() => _SubjectHubScreenState();
}

class _SubjectHubScreenState extends State<SubjectHubScreen>
    with SingleTickerProviderStateMixin {
  bool _isSyncing = false;
  late AnimationController _syncController;
  final GamificationService _gamificationService = GamificationService();
  final SubjectStatsService _statsService = SubjectStatsService();
  final SpacedRepetitionService _srsService = SpacedRepetitionService();
  final ExamGeneratorService _generatorService = ExamGeneratorService();
  GamificationProfile? _profile;

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = context.read<AuthService>().user?.uid;
    if (userId == null) return;
    
    final profile = await _gamificationService.getProfile(userId);
    if (mounted) setState(() => _profile = profile);
  }

  @override
  void dispose() {
    _syncController.dispose();
    super.dispose();
  }

  void _onSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    _syncController.repeat();
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(seconds: 2));
    _syncController.stop();
    _syncController.reset();
    if (mounted) setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final headerStatsHeight = 160.0;
    final availableHeight = screenHeight - appBarHeight - headerStatsHeight - 100;
    
    final double cardHeight = (availableHeight / 3).clamp(120.0, 180.0);
    final double cardWidth = (MediaQuery.of(context).size.width - 56) / 2;
    final double aspectRatio = cardWidth / cardHeight;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PerformanceScreen(
                    subjectId: widget.subjectId,
                    subjectName: widget.subjectName,
                  ),
                ),
              ),
              child: _buildHeaderStats(),
            ),
          ),

          _buildSmartCoachSliver(),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: aspectRatio,
              ),
              delegate: SliverChildListDelegate([
                _buildActionCard(0, Icons.assignment_rounded, 'الامتحانات', const Color(0xFF2563EB), _statsService.streamExamsCount(widget.subjectId)),
                _buildActionCard(1, Icons.sell_rounded, 'التصنيفات', const Color(0xFFEA580C), _statsService.streamTopicsCount(widget.subjectId)),
                _buildActionCard(2, Icons.search_rounded, 'البحث', const Color(0xFF16A34A), Stream.value(0)),
                _buildActionCard(3, Icons.favorite_rounded, 'المفضلة', const Color(0xFFEF4444), _statsService.streamFavoritesCount(context.read<AuthService>().user?.uid ?? '', widget.subjectId)),
                _buildActionCard(4, Icons.close_rounded, 'الإجابات الخاطئة', const Color(0xFFDC2626), _statsService.streamWrongAnswersCount(context.read<AuthService>().user?.uid ?? '', widget.subjectId)),
                _buildActionCard(5, Icons.school_rounded, 'تدرب بنفسك', const Color(0xFF0EA5E9), Stream.value(0)),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildActionCard(int index, IconData icon, String label, Color bg, Stream<int> countStream) {
    return StreamBuilder<int>(
      stream: countStream,
      initialData: 0,
      builder: (context, snapshot) {
        return HubActionCard(
          action: HubAction(
            icon: icon,
            label: label,
            iconColor: Colors.white,
            iconBackground: bg,
            badgeCount: snapshot.data ?? 0,
          ),
          onTap: () => _onActionTap(index),
        );
      }
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المستوى ${_profile?.level ?? 1}',
                    style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'الإتقان الكلي للمادة: 65%',
                    style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              _buildGamificationInfo(),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.65,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamificationInfo() {
    return Row(
      children: [
        _buildStatItem(Icons.bolt_rounded, '${_profile?.xp ?? 0}', Colors.amber),
        const SizedBox(width: 12),
        _buildStatItem(Icons.local_fire_department_rounded, '${_profile?.currentStreak ?? 0}', Colors.orange),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      pinned: true,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          onPressed: _onSync,
          icon: RotationTransition(
            turns: _syncController,
            child: Icon(
              Icons.sync_rounded,
              color: _isSyncing ? AppColors.primaryBlue : AppColors.textSecondary,
              size: 24,
            ),
          ),
        ),
      ],
      title: Text(
        widget.subjectName,
        style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
      centerTitle: true,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
      ),
    );
  }

  void _onActionTap(int index) {
    HapticFeedback.selectionClick();
    switch (index) {
      case 0: // الامتحانات
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExamsListScreen(
              subjectId: widget.subjectId,
              subjectName: widget.subjectName,
            ),
          ),
        );
        break;
      case 1: // التصنيفات
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubjectTagsScreen(
              subjectId: widget.subjectId,
              subjectName: widget.subjectName,
            ),
          ),
        );
        break;
      case 2: // البحث
        _showComingSoon('البحث');
        break;
      case 3: // المفضلة
        _showComingSoon('المفضلة');
        break;
      case 4: // الإجابات الخاطئة
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WrongAnswersScreen(subjectName: widget.subjectName),
          ),
        );
        break;
      case 5: // تدرب بنفسك
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PracticeScreen(
              subjectId: widget.subjectId,
              subjectName: widget.subjectName,
            ),
          ),
        );
        break;
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('قريباً: $feature', style: GoogleFonts.cairo(), textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSmartCoachSliver() {
    final userId = context.read<AuthService>().user?.uid;
    if (userId == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return StreamBuilder<int>(
      stream: _statsService.streamDueQuestionsCount(userId, widget.subjectId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: SmartCoachBanner(
            message: 'لديك $count سؤالاً حان موعد مراجعتها لتثبيتها في ذاكرتك!',
            actionLabel: 'راجع الآن',
            onAction: () => _startSmartReview(userId),
          ),
        );
      },
    );
  }

  Future<void> _startSmartReview(String userId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final dueIds = await _srsService.getDueQuestionIds(userId, widget.subjectId);
      final questions = await _generatorService.getQuestionsByIds(dueIds);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loader

      if (questions.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveRecallSessionScreen(
            config: ExamConfig(
              title: 'مراجعة ذكية',
              subjectId: widget.subjectId,
              durationSeconds: questions.length * 60,
              totalQuestions: questions.length,
              type: ExamType.bank,
              passingScore: 60.0,
              sectionId: 'smart_review',
            ),
            questions: questions,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب الأسئلة: $e')),
        );
      }
    }
  }
}
