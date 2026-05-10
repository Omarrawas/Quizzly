import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/presentation/widgets/hub_action_card.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/domain/services/smart_notification_service.dart';
import 'package:quizzly/features/quiz/domain/services/cram_mode_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/cram_mode_session_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/mastery_dashboard_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/subject_explore_screen.dart';
import 'package:quizzly/features/subject/domain/services/subject_stats_service.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/subject/presentation/widgets/smart_coach_banner.dart';
import 'package:quizzly/features/subject/presentation/screens/practical_section_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/practice_screen.dart';
import 'package:quizzly/features/subject/domain/services/readiness_service.dart';
import 'package:quizzly/features/subject/presentation/screens/subject_battles_screen.dart';

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

class _SubjectHubScreenState extends State<SubjectHubScreen> {
  final SubjectStatsService _statsService = SubjectStatsService();
  final CramModeService _cramModeService = CramModeService();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final userId = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(userId),
          SliverToBoxAdapter(child: _buildReadinessHeader(userId)),
          SliverToBoxAdapter(child: _buildDynamicCoachBanner(userId)),
          _buildCramModeSliver(userId),
          SliverToBoxAdapter(
            child: _buildActionsGrid(userId),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Dynamic banner: only shown when readiness score < 50%
  Widget _buildDynamicCoachBanner(String userId) {
    return StreamBuilder<double>(
      stream: ReadinessService().streamReadinessScore(userId, widget.subjectId),
      builder: (context, snapshot) {
        final score = snapshot.data ?? 0.0;
        // Only show the banner when the student genuinely has gaps
        if (score >= 0.5) return const SizedBox.shrink();
        return SmartCoachBanner(
          message: 'لديك فجوات في تغطية المنهج، هل تريد مراجعتها الآن؟',
          actionLabel: 'مراجعة فورية',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PracticalSectionScreen(
                  subjectId: widget.subjectId,
                  subjectName: widget.subjectName,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReadinessHeader(String userId) {
    return StreamBuilder<double>(
      stream: ReadinessService().streamReadinessScore(userId, widget.subjectId),
      builder: (context, snapshot) {
        final score = snapshot.data ?? 0.0;
        final percentage = (score * 100).toInt();

        Color statusColor = Colors.redAccent;
        String statusText = 'غير مستعد';
        if (score > 0.8) {
          statusColor = Colors.greenAccent;
          statusText = 'مستعد تماماً';
        } else if (score > 0.5) {
          statusColor = Colors.amberAccent;
          statusText = 'جاهزية متوسطة';
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نسبة الاستعداد للامتحان',
                      style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: GoogleFonts.cairo(color: statusColor, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'بناءً على إتقانك وتغطية المنهج',
                      style: GoogleFonts.cairo(color: Colors.white30, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: score,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  Text(
                    '%$percentage',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  SliverAppBar _buildSliverAppBar(String userId) {
    return SliverAppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      pinned: true,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          onPressed: () => _showMasteryMap(context, userId),
          icon: const Icon(Icons.map_outlined, color: AppColors.textPrimary, size: 24),
          tooltip: 'خارطة الإتقان',
        ),
        IconButton(
          onPressed: () => SmartNotificationService().sendSampleFlashQuiz(),
          icon: const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 24),
        ),
      ],
      title: Text(
        widget.subjectName,
        style: GoogleFonts.cairo(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  // Grid built with a normal GridView (not SliverGrid) to avoid height calculation issues
  Widget _buildActionsGrid(String userId) {
    final List<(IconData, String, Color, Stream<int>, int)> actions = [
      (Icons.assignment_rounded,          'الامتحانات',       const Color(0xFF2563EB), _statsService.streamExamsCount(widget.subjectId),              0),
      (Icons.explore_rounded,             'استكشاف المحتوى',  const Color(0xFF6366F1), _statsService.streamTopicsCount(widget.subjectId),              1),
      (Icons.auto_awesome_motion_rounded, 'مركز الإتقان',     const Color(0xFF0F172A), _statsService.streamWrongAnswersCount(userId, widget.subjectId), 2),
      (Icons.school_rounded,              'تدرب بنفسك',       const Color(0xFF0EA5E9), _statsService.streamPracticeCount(userId, widget.subjectId),     3),
      (Icons.science_rounded,             'القسم العملي',     const Color(0xFF0D9488), _statsService.streamPracticalTopicsCount(widget.subjectId),      4),
      (Icons.groups_rounded,              'معارك المواد',     const Color(0xFFE11D48), Stream<int>.value(0),                                            5),
    ];

    // 3 rows × 160px each + spacing
    const double cardHeight = 160;
    const double spacing = 16;
    const int rows = 3;
    const double gridHeight = rows * cardHeight + (rows - 1) * spacing;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: gridHeight,
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 1.1,
          physics: const NeverScrollableScrollPhysics(),
          children: actions.map((a) => _buildActionCard(
            icon: a.$1,
            label: a.$2,
            color: a.$3,
            countStream: a.$4,
            onTap: () => _onActionTap(a.$5),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required Stream<int> countStream,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return HubActionCard(
          action: HubAction(
            icon: icon,
            label: label,
            iconColor: color,
            iconBackground: color.withValues(alpha: 0.1),
            badgeCount: count,
          ),
          onTap: onTap,
        );
      },
    );
  }

  Widget _buildCramModeSliver(String userId) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<QuizQuestion>>(
        future: _cramModeService.generateCramSession(userId, widget.subjectId),
        builder: (context, snapshot) {
          // Still loading — don't block the rest of the UI
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          // Error or empty — hide gracefully
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }
          final count = snapshot.data!.length;

          return Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.offline_bolt_rounded, color: Colors.amber, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'وضع اللمسات الأخيرة',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'لديك $count سؤال تحتاج لمراجعتها الآن',
                        style: GoogleFonts.cairo(fontSize: 12, color: Colors.amber[900]),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CramModeSessionScreen(
                        questions: snapshot.data!,
                        subjectId: widget.subjectId,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('ابدأ الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onActionTap(int index) {
    switch (index) {
      case 0:
        // Exams — coming soon
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('قسم الامتحانات قادم في التحديث القادم!')),
        );
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectExploreScreen(subjectId: widget.subjectId, subjectName: widget.subjectName)));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => MasteryDashboardScreen(subjectId: widget.subjectId, subjectName: widget.subjectName)));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => PracticeScreen(subjectId: widget.subjectId, subjectName: widget.subjectName)));
        break;
      case 4:
        Navigator.push(context, MaterialPageRoute(builder: (_) => PracticalSectionScreen(subjectId: widget.subjectId, subjectName: widget.subjectName)));
        break;
      case 5:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubjectBattlesScreen(
              subjectId: widget.subjectId,
              subjectName: widget.subjectName,
            ),
          ),
        );
        break;
    }
  }

  void _showMasteryMap(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MasteryMapSheet(userId: userId, subjectId: widget.subjectId),
    );
  }
}

class _MasteryMapSheet extends StatelessWidget {
  final String userId;
  final String subjectId;
  const _MasteryMapSheet({required this.userId, required this.subjectId});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'خارطة إتقان المادة',
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<Map<String, double>>(
              future: ReadinessService().getTopicReadiness(userId, subjectId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }
                final topics = snapshot.data ?? {};
                if (topics.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد بيانات كافية بعد.\nابدأ بحل بعض الأسئلة لترى تحليل إتقانك هنا.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(color: Colors.white54, height: 1.6),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: topics.length,
                  itemBuilder: (context, index) {
                    final score = topics.values.elementAt(index);
                    final color = score > 0.8 ? Colors.greenAccent : (score > 0.4 ? Colors.amberAccent : Colors.redAccent);
                    return ListTile(
                      leading: Icon(Icons.circle, color: color, size: 12),
                      title: Text('موضوع رقم ${index + 1}', style: GoogleFonts.cairo(color: Colors.white)),
                      trailing: Text(
                        '%${(score * 100).toInt()}',
                        style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
