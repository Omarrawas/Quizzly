import 'package:flutter/material.dart';
import 'package:quizzly/features/auth/domain/services/activation_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/presentation/screens/subject_league_screen.dart';
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
import 'package:quizzly/features/admin/domain/services/database_service.dart';
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
  late String _contentSubjectId;
  String? _checkedUserId;

  @override
  void initState() {
    super.initState();
    _contentSubjectId = widget.subjectId;
    _resolveContentSubjectId();
  }

  @override
  void didUpdateWidget(covariant SubjectHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId) {
      setState(() {
        _contentSubjectId = widget.subjectId;
        _isActivated = false;
        _checkingActivation = true;
        _checkedUserId = null;
      });
      _resolveContentSubjectId();
    }
  }

  Future<void> _resolveContentSubjectId() async {
    final targetId = widget.subjectId;
    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await FirebaseFirestore.instance
            .collection('subjects')
            .doc(targetId)
            .get()
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        doc = await FirebaseFirestore.instance
            .collection('subjects')
            .doc(targetId)
            .get(const GetOptions(source: Source.cache));
      }

      if (doc.exists && mounted && targetId == widget.subjectId) {
        final data = doc.data();
        if (data != null && data['referenceSubjectId'] != null) {
          final refId = data['referenceSubjectId'] as String;
          if (refId.isNotEmpty) {
            setState(() {
              _contentSubjectId = refId;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _checkActivationForUser(String userId) async {
    final targetSubjectId = widget.subjectId;
    bool active = false;
    try {
      // Try primary activation check with a reasonable timeout
      active = await _activationService
          .isSubjectActivated(userId, targetSubjectId)
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
    } catch (_) {
      // Fallback to cache if primary check fails or times out
      try {
        final cachedDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('active_subjects')
            .doc(targetSubjectId)
            .get(const GetOptions(source: Source.cache));
        active = cachedDoc.exists;
      } catch (_) {
        active = false;
      }
    }
    if (mounted && targetSubjectId == widget.subjectId) {
      setState(() {
        _isActivated = active;
        _checkingActivation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = context.watch<AuthService>().user;
    if (user == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_checkedUserId != user.uid) {
      _checkedUserId = user.uid;
      _checkingActivation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkActivationForUser(user.uid);
      });
    }

    if (_checkingActivation) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final userId = user.uid;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(userId, theme, isDark),
          SliverToBoxAdapter(child: _buildReadinessHeader(userId, isDark)),
          SliverToBoxAdapter(child: _buildDynamicCoachBanner(userId)),
          _buildCramModeSliver(userId, isDark),
          SliverToBoxAdapter(child: _buildActionsLayout(userId, isDark)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Dynamic banner: only shown when readiness score < 50%
  Widget _buildDynamicCoachBanner(String userId) {
    if (!_isActivated) {
      return const SizedBox.shrink(); // Hide coach for free users to keep it clean
    }
    return StreamBuilder<double>(
      stream: ReadinessService().streamReadinessScore(
        userId,
        _contentSubjectId,
      ),
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
                  subjectId: _contentSubjectId,
                  subjectName: widget.subjectName,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReadinessHeader(String userId, bool isDark) {
    return StreamBuilder<double>(
      stream: ReadinessService().streamReadinessScore(
        userId,
        _contentSubjectId,
      ),
      builder: (context, snapshot) {
        final score = snapshot.data ?? 0.0;
        final percentage = (score * 100).toInt();

        Color statusColor = const Color(
          0xFFFBBF24,
        ); // Warm orange/yellow from screenshot
        String statusText = 'جاهزية متوسطة';
        if (score > 0.8) {
          statusColor = const Color(0xFF10B981); // Emerald Green
          statusText = 'مستعد تماماً';
        } else if (score < 0.5) {
          statusColor = const Color(0xFFEF4444); // Red
          statusText = 'غير مستعد';
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey[200]!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.02),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Circular progress on the LEFT
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: score,
                      strokeWidth: 9,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey[200]!,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  Text(
                    '%$percentage',
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Texts on the RIGHT (takes remaining space)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نسبة الاستعداد للامتحان',
                      style: GoogleFonts.cairo(
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondary,
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
                      _isActivated
                          ? 'بناءً على إتقانك وتغطية المنهج'
                          : 'اشترك لتفعيل خارطة الإتقان الكاملة',
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white30 : Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  SliverAppBar _buildSliverAppBar(String userId, ThemeData theme, bool isDark) {
    final canPop = Navigator.canPop(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return SliverAppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      pinned: true,
      centerTitle: true,
      // Back button on leading (which is right side in RTL Arabic)
      leading: canPop
          ? IconButton(
              icon: Icon(
                isRtl
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : AppColors.textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      // Mastery Map icon on actions (which is left side in RTL Arabic)
      actions: [
        IconButton(
          onPressed: () => _showMasteryMap(context, userId),
          icon: Icon(
            Icons.map_outlined,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 24,
          ),
          tooltip: 'خارطة الإتقان',
        ),
      ],
      title: Text(
        widget.subjectName,
        style: GoogleFonts.cairo(
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildPremiumActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required bool isLocked,
    required int badgeCount,
    required bool showBadge,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey[200]!,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Centered Main Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon container with gorgeous glow
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 26, color: color),
                  ),
                  const SizedBox(height: 14),
                  // Label
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Lock icon in the top-right
            if (isLocked)
              Positioned(
                top: -8,
                right: -8,
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: color.withValues(alpha: 0.6),
                  size: 16,
                ),
              ),

            // Badge icon in the top-left (RTL)
            if (showBadge && badgeCount > 0)
              Positioned(
                top: -8,
                left: -8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(
                      0xFF5F5DFA,
                    ), // Indigo/purple badge from screenshot
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 19,
                    minHeight: 19,
                  ),
                  child: Center(
                    child: Text(
                      '$badgeCount',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsLayout(String userId, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sections')
          .where('parentId', isEqualTo: _contentSubjectId)
          .snapshots(),
      builder: (context, snapshot) {
        final sections = snapshot.data?.docs ?? [];
        bool showPractical = false;
        bool showTheoretical = false;

        for (var doc in sections) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name']?.toString() ?? '';
          final isHidden = data['isHidden'] == true;
          if (name.contains('عملي') && !isHidden) {
            showPractical = true;
          }
          if (name.contains('نظري') && !isHidden) {
            showTheoretical = true;
          }
        }

        final List<(IconData, String, Color, Stream<int>, int, bool)>
        gridActions = [
          (
            Icons.assignment_rounded,
            'الامتحانات',
            const Color(0xFF8B93FF), // Purple theme color
            _statsService.streamExamsCount(_contentSubjectId),
            0,
            false,
          ),
          (
            Icons.explore_rounded,
            'استكشاف المحتوى',
            const Color(0xFF6366F1), // Blue theme color
            _statsService.streamTopicsCount(_contentSubjectId),
            1,
            !_isActivated,
          ),
          (
            Icons.auto_awesome_motion_rounded,
            'مركز الإتقان',
            isDark
                ? Colors.white60
                : const Color(0xFF475569), // Slate theme color
            _statsService.streamWrongAnswersCount(userId, _contentSubjectId),
            2,
            !_isActivated,
          ),
          (
            Icons.school_rounded,
            'تدرب بنفسك',
            const Color(0xFF0EA5E9), // Cyan/Teal theme color
            _statsService.streamPracticeCount(userId, _contentSubjectId),
            3,
            !_isActivated,
          ),
          if (showPractical)
            (
              Icons.science_rounded,
              'القسم العملي',
              const Color(0xFF0D9488), // Green/Teal beaker color
              _statsService.streamPracticalTopicsCount(_contentSubjectId),
              4,
              false,
            ),
          (
            Icons.groups_rounded,
            'معارك المواد',
            const Color(0xFFE11D48), // Pink/Crimson color
            Stream<int>.value(0),
            5,
            !_isActivated,
          ),
          if (showTheoretical)
            (
              Icons.menu_book_rounded,
              'دروس النظري',
              const Color(0xFF8B5CF6), // Violet theme color
              _statsService.streamTopicsCount(_contentSubjectId),
              6,
              false,
            ),
          (
            Icons.emoji_events_rounded,
            'دوري التحدي',
            const Color(0xFFF59E0B), // Amber/Gold
            Stream<int>.value(0),
            7,
            false,
          ),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.15,
            ),
            itemCount: gridActions.length,
            itemBuilder: (context, index) {
              final a = gridActions[index];
              return StreamBuilder<int>(
                stream: a.$4,
                builder: (context, countSnap) {
                  final count = countSnap.data ?? 0;
                  final showBadge = a.$5 == 0 || (a.$5 == 1 && count > 0);

                  return _buildPremiumActionCard(
                    icon: a.$1,
                    label: a.$2,
                    color: a.$3,
                    isLocked: a.$6,
                    badgeCount: count,
                    showBadge: showBadge,
                    onTap: () => _onActionTap(a.$5),
                    isDark: isDark,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCramModeSliver(String userId, bool isDark) {
    if (!_isActivated) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: FutureBuilder<List<QuizQuestion>>(
        future: _cramModeService.generateCramSession(userId, _contentSubjectId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
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
              color: isDark
                  ? const Color(0xFF1E1711)
                  : Colors.amber[50]!.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF92400E).withValues(alpha: 0.5)
                    : Colors.amber[200]!,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // 1. Far Left: "ابدأ الآن" button
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CramModeSessionScreen(
                        questions: snapshot.data!,
                        subjectId: _contentSubjectId,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFFBBF24,
                    ), // Yellow background
                    foregroundColor: Colors.black,
                    elevation: 0,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'ابدأ الآن',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Middle: Title & Subtitle aligned to the right (Expanded)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'وضع اللمسات الأخيرة',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark
                              ? const Color(0xFFFBBF24)
                              : Colors.amber[900],
                        ),
                      ),
                      Text(
                        'لديك $count سؤال تحتاج لمراجعتها الآن',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          color: isDark ? Colors.white70 : Colors.amber[950],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 3. Far Right: Lightning bolt circular badge
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFFBBF24),
                    size: 20,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.withValues(alpha: 0.1)
                    : Colors.amber[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.amber,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'افتح المحتوى الكامل الآن',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'اشترك لتتمكن من الوصول لجميع الدروس، الاختبارات، وتحليل الأخطاء المتقدم.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: isDark ? Colors.white60 : AppColors.textSecondary,
                height: 1.5,
              ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'تفعيل المادة بالكود',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ربما لاحقاً',
                style: GoogleFonts.cairo(
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'تفعيل المادة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'يرجى إدخال كود تفعيل مادة ${widget.subjectName} لفتح جميع المميزات.',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'أدخل الكود هنا...',
                  hintStyle: GoogleFonts.cairo(
                    fontSize: 13,
                    color: isDark ? Colors.white24 : Colors.grey[400],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
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
                          SnackBar(
                            content: Text(
                              result['message'],
                              style: GoogleFonts.cairo(),
                            ),
                          ),
                        );
                        // Refresh Hub
                        setState(() {
                          _isActivated = true;
                          _checkingActivation = true;
                        });
                        _checkActivationForUser(userId);
                      } else {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['message'],
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'تفعيل الآن',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
            subjectId: _contentSubjectId,
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
            subjectId: _contentSubjectId,
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
            subjectId: _contentSubjectId,
            subjectName: widget.subjectName,
            isFree: !_isActivated,
          ),
        ),
      );
      return;
    }

    // 4. Practical Section (Allows entry for free users, locks applied inside)
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PracticalSectionScreen(
            subjectId: _contentSubjectId,
            subjectName: widget.subjectName,
            isViewOnly: true,
            isFree: !_isActivated,
          ),
        ),
      );
      return;
    }

    // 5. Theoretical Lessons (Allows entry for free users, locks applied inside)
    if (index == 6) {
      _navigateToLessons();
      return;
    }

    // 7. Challenge League
    if (index == 7) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubjectLeagueScreen(
            subjectId: _contentSubjectId,
            subjectName: widget.subjectName,
          ),
        ),
      );
      return;
    }

    // Other sections (Locked for free users)
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
              subjectId: _contentSubjectId,
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
              subjectId: _contentSubjectId,
              subjectName: widget.subjectName,
            ),
          ),
        );
        break;
    }
  }

  void _navigateToLessons() async {
    // 1. Try to find a section that explicitly contains 'نظري' in its name
    final sectionsSnap = await FirebaseFirestore.instance
        .collection(DatabaseService.colSections)
        .where('parentId', isEqualTo: _contentSubjectId)
        .get();

    String? theorySectionId;
    String? theorySectionName;

    // First pass: look for 'نظري'
    for (var doc in sectionsSnap.docs) {
      final name = (doc.data()['name'] ?? '').toString();
      if (name.contains('نظري')) {
        theorySectionId = doc.id;
        theorySectionName = name;
        break;
      }
    }

    // Second pass: if not found and there is only ONE section, use it
    if (theorySectionId == null && sectionsSnap.docs.length == 1) {
      theorySectionId = sectionsSnap.docs.first.id;
      theorySectionName =
          sectionsSnap.docs.first.data()['name'] ?? 'القسم النظري';
    }

    // Third pass: check for any lessons directly under the subject (legacy support)
    if (theorySectionId == null) {
      final lessonsSnap = await FirebaseFirestore.instance
          .collection(DatabaseService.colTopics)
          .where('subjectId', isEqualTo: _contentSubjectId)
          .where('type', isEqualTo: 'lesson')
          .limit(1)
          .get();

      if (lessonsSnap.docs.isNotEmpty) {
        // We found lessons, use the sectionId from the first lesson if it exists
        theorySectionId = lessonsSnap.docs.first.data()['sectionId'];
        theorySectionName = 'القسم النظري';
      }
    }

    if (!mounted) return;

    if (theorySectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على القسم النظري لهذه المادة'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TheoreticalLessonListScreen(
          subjectId: _contentSubjectId,
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
          _MasteryMapSheet(userId: userId, subjectId: _contentSubjectId),
    );
  }
}

class _MasteryMapSheet extends StatelessWidget {
  final String userId;
  final String subjectId;
  const _MasteryMapSheet({required this.userId, required this.subjectId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : const Color(
                0xFF0F172A,
              ), // Keep it dark as it's a premium sheet style
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
