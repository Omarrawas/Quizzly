import 'package:flutter/material.dart';
import 'package:quizzly/features/auth/domain/services/activation_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/presentation/widgets/hub_action_card.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/quiz/domain/services/cram_mode_service.dart';
import 'package:quizzly/features/quiz/presentation/screens/cram_mode_session_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/mastery_dashboard_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/subject_explore_screen.dart';
import 'package:quizzly/features/subject/domain/services/subject_stats_service.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/subject/presentation/widgets/smart_coach_banner.dart';
import 'package:quizzly/features/subject/presentation/screens/practical_section_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/practice_screen.dart';
import 'package:quizzly/features/subject/domain/services/readiness_service.dart';
import 'package:quizzly/features/subject/presentation/screens/subject_battles_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/lists_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/subject/presentation/screens/theoretical_lesson_list_screen.dart';

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
  final ActivationService _activationService = ActivationService();
  bool _isActivated = false;
  bool _checkingActivation = true;

  @override
  void initState() {
    super.initState();
    _checkActivation();
  }

  Future<void> _checkActivation() async {
    final userId = context.read<AuthService>().user?.uid;
    if (userId != null) {
      final active = await _activationService.isSubjectActivated(userId, widget.subjectId);
      if (mounted) {
        setState(() {
          _isActivated = active;
          _checkingActivation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null || _checkingActivation) {
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
          SliverToBoxAdapter(child: _buildActionsGrid(userId)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Dynamic banner: only shown when readiness score < 50%
  Widget _buildDynamicCoachBanner(String userId) {
    if (!_isActivated) return const SizedBox.shrink(); // Hide coach for free users to keep it clean
    return StreamBuilder<double>(
      stream: ReadinessService().streamReadinessScore(userId, widget.subjectId),
      builder: (context, snapshot) {
        final score = snapshot.data ?? 0.0;
        if (score >= 0.5) return const SizedBox.shrink();
        return SmartCoachBanner(
          message: 'لديك فجوات في تغطية المنهج، هل تريد مراجعتها الآن؟',
          actionLabel: 'مراجعة فورية',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PracticeScreen(
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
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: GoogleFonts.cairo(
                        color: statusColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isActivated ? 'بناءً على إتقانك وتغطية المنهج' : 'اشترك لتفعيل خارطة الإتقان الكاملة',
                      style: GoogleFonts.cairo(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
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
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
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
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          onPressed: () => _showMasteryMap(context, userId),
          icon: const Icon(
            Icons.map_outlined,
            color: AppColors.textPrimary,
            size: 24,
          ),
          tooltip: 'خارطة الإتقان',
        ),
      ],
      title: Text(
        widget.subjectName,
        style: GoogleFonts.cairo(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  // Grid built with a normal GridView (not SliverGrid) to avoid height calculation issues
  Widget _buildActionsGrid(String userId) {
    final List<(IconData, String, Color, Stream<int>, int, bool)> actions = [
      (
        Icons.assignment_rounded,
        'الامتحانات',
        const Color(0xFF2563EB),
        _statsService.streamExamsCount(widget.subjectId),
        0,
        false, // Always protected at exam level
      ),
      (
        Icons.explore_rounded,
        'استكشاف المحتوى',
        const Color(0xFF6366F1),
        _statsService.streamTopicsCount(widget.subjectId),
        1,
        !_isActivated, // Show lock if not activated
      ),
      (
        Icons.auto_awesome_motion_rounded,
        'مركز الإتقان',
        const Color(0xFF0F172A),
        _statsService.streamWrongAnswersCount(userId, widget.subjectId),
        2,
        !_isActivated,
      ),
      (
        Icons.school_rounded,
        'تدرب بنفسك',
        const Color(0xFF0EA5E9),
        _statsService.streamPracticeCount(userId, widget.subjectId),
        3,
        !_isActivated,
      ),
      (
        Icons.science_rounded,
        'القسم العملي',
        const Color(0xFF0D9488),
        _statsService.streamPracticalTopicsCount(widget.subjectId),
        4,
        !_isActivated,
      ),
      (
        Icons.groups_rounded,
        'معارك المواد',
        const Color(0xFFE11D48),
        Stream<int>.value(0),
        5,
        !_isActivated,
      ),
      (
        Icons.menu_book_rounded,
        'تصفح الدروس',
        const Color(0xFF8B5CF6),
        _statsService.streamTopicsCount(widget.subjectId), // Using topic count as a proxy
        6,
        !_isActivated,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final a = actions[index];
          return _buildActionCard(
            icon: a.$1,
            label: a.$2,
            color: a.$3,
            countStream: a.$4,
            showBadge: index < 2,
            isLocked: a.$6,
            onTap: () => _onActionTap(a.$5),
          );
        },
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required Stream<int> countStream,
    required bool showBadge,
    required bool isLocked,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          children: [
            HubActionCard(
              action: HubAction(
                icon: icon,
                label: label,
                iconColor: color,
                iconBackground: color.withValues(alpha: 0.1),
                badgeCount: count,
                showBadge: showBadge,
              ),
              onTap: onTap,
            ),
            if (isLocked)
              Positioned(
                top: 12,
                right: 12,
                child: Icon(Icons.lock_outline_rounded, color: color.withValues(alpha: 0.5), size: 16),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCramModeSliver(String userId) {
    if (!_isActivated) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: FutureBuilder<List<QuizQuestion>>(
        future: _cramModeService.generateCramSession(userId, widget.subjectId),
        builder: (context, snapshot) {
          // Still loading — don't block the rest of the UI
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          // Error or empty — hide gracefully
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
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
                const Icon(
                  Icons.offline_bolt_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'وضع اللمسات الأخيرة',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'لديك $count سؤال تحتاج لمراجعتها الآن',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.amber[900],
                        ),
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
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'ابدأ الآن',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPaywall() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.amber[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 32),
            ),
            const SizedBox(height: 24),
            Text(
              'افتح المحتوى الكامل الآن',
              style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'اشترك لتتمكن من الوصول لجميع الدروس، الاختبارات، وتحليل الأخطاء المتقدم.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showActivationDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('تفعيل المادة بالكود', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ربما لاحقاً', style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showActivationDialog() {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تفعيل المادة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'يرجى إدخال كود تفعيل مادة ${widget.subjectName} لفتح جميع المميزات.',
                style: GoogleFonts.cairo(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'أدخل الكود هنا...',
                  hintStyle: GoogleFonts.cairo(fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (controller.text.isEmpty) return;
                
                setDialogState(() => isLoading = true);
                final userId = context.read<AuthService>().user?.uid;
                final result = await _activationService.activateWithCode(
                  userId: userId!,
                  code: controller.text,
                  subjectId: widget.subjectId,
                );
                
                if (!mounted) return;
                setDialogState(() => isLoading = false);

                if (result['success']) {
                  if (!context.mounted) return;
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'], style: GoogleFonts.cairo())),
                  );
                  // Refresh Hub
                  setState(() => _isActivated = true);
                  _checkActivation();
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'], style: GoogleFonts.cairo()), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('تفعيل الآن', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _onActionTap(int index) {
    // 1. Exams (Allows entry for free users, limits applied inside)
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExamsListScreen(
            subjectId: widget.subjectId,
            subjectName: widget.subjectName,
            isFree: !_isActivated,
          ),
        ),
      );
      return;
    }

    // 2. Explore (Allows entry for free users, limits applied inside)
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubjectExploreScreen(
            subjectId: widget.subjectId,
            subjectName: widget.subjectName,
            isFree: !_isActivated,
          ),
        ),
      );
      return;
    }

    // 3. Practice (Allows entry for free users, limits applied inside)
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PracticeScreen(
            subjectId: widget.subjectId,
            subjectName: widget.subjectName,
            isFree: !_isActivated,
          ),
        ),
      );
      return;
    }

    // 4. Other sections (Locked for free users)
    if (!_isActivated) {
      _showPaywall();
      return;
    }

    switch (index) {
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MasteryDashboardScreen(
              subjectId: widget.subjectId,
              subjectName: widget.subjectName,
            ),
          ),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PracticalSectionScreen(
              subjectId: widget.subjectId,
              subjectName: widget.subjectName,
            ),
          ),
        );
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
      case 6:
        // For lessons, we need to know the section ID. 
        // Usually, 'Theoretical' is the default section for bank questions.
        // I'll fetch the theory section ID or use a default one.
        _navigateToLessons();
        break;
    }
  }

  void _navigateToLessons() async {
    // We need to find the theoretical section ID.
    // In this app, the theory section is usually named 'القسم النظري' or similar.
    final sectionsSnap = await FirebaseFirestore.instance
        .collection('sections')
        .where('subjectId', isEqualTo: widget.subjectId)
        .get();
    
    String? theorySectionId;
    String? theorySectionName;
    
    for (var doc in sectionsSnap.docs) {
      final name = doc.data()['name'] ?? '';
      if (name.contains('نظري')) {
        theorySectionId = doc.id;
        theorySectionName = name;
        break;
      }
    }

    // Fallback if not found
    theorySectionId ??= 'theory_default';
    theorySectionName ??= 'القسم النظري';

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TheoreticalLessonListScreen(
          subjectId: widget.subjectId,
          subjectName: widget.subjectName,
          sectionId: theorySectionId!,
          sectionName: theorySectionName!,
          isFree: !_isActivated,
          isAdmin: false,
        ),
      ),
    );
  }

  void _showMasteryMap(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _MasteryMapSheet(userId: userId, subjectId: widget.subjectId),
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
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'خارطة إتقان المادة',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<Map<String, double>>(
              future: ReadinessService().getTopicReadiness(userId, subjectId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }
                final topics = snapshot.data ?? {};
                if (topics.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد بيانات كافية بعد.\nابدأ بحل بعض الأسئلة لترى تحليل إتقانك هنا.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: Colors.white54,
                        height: 1.6,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: topics.length,
                  itemBuilder: (context, index) {
                    final score = topics.values.elementAt(index);
                    final color = score > 0.8
                        ? Colors.greenAccent
                        : (score > 0.4 ? Colors.amberAccent : Colors.redAccent);
                    return ListTile(
                      leading: Icon(Icons.circle, color: color, size: 12),
                      title: Text(
                        topics.keys.elementAt(index),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Text(
                        '%${(score * 100).toInt()}',
                        style: GoogleFonts.cairo(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
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
