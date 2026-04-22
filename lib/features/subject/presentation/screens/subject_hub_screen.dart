import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/presentation/widgets/hub_action_card.dart';
import 'package:quizzly/features/subject/presentation/screens/lists_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/wrong_answers_screen.dart';
import 'package:quizzly/features/search/presentation/screens/search_filter_screen.dart';
import 'package:quizzly/features/training/presentation/screens/training_sessions_screen.dart';

class SubjectHubScreen extends StatefulWidget {
  final String subjectName;

  const SubjectHubScreen({super.key, this.subjectName = 'الكيمياء'});

  @override
  State<SubjectHubScreen> createState() => _SubjectHubScreenState();
}

class _SubjectHubScreenState extends State<SubjectHubScreen>
    with SingleTickerProviderStateMixin {
  bool _isSyncing = false;
  late AnimationController _syncController;

  // ── الأزرار الستة ─────────────────────────────────────
  late final List<HubAction> _actions = [
    const HubAction(
      icon: Icons.assignment_rounded,
      label: 'الامتحانات',
      iconColor: Colors.white,
      iconBackground: Color(0xFF2563EB),
      badgeCount: 23,
    ),
    const HubAction(
      icon: Icons.label_rounded,
      label: 'التصنيفات',
      iconColor: Colors.white,
      iconBackground: Color(0xFFEA580C),
      badgeCount: 11,
    ),
    const HubAction(
      icon: Icons.search_rounded,
      label: 'البحث',
      iconColor: Colors.white,
      iconBackground: Color(0xFF16A34A),
      badgeCount: 0,
    ),
    const HubAction(
      icon: Icons.favorite_rounded,
      label: 'المفضلة',
      iconColor: Colors.white,
      iconBackground: Color(0xFFDC2626),
      badgeCount: 6,
    ),
    const HubAction(
      icon: Icons.school_rounded,
      label: 'تدرب بنفسك',
      iconColor: Colors.white,
      iconBackground: Color(0xFF1D4ED8),
      badgeCount: 0,
    ),
    const HubAction(
      icon: Icons.cancel_rounded,
      label: 'الإجابات الخاطئة',
      iconColor: Colors.white,
      iconBackground: Color(0xFFDC2626),
      badgeCount: 0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
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

  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [_buildSliverAppBar()],
        body: _buildGrid(),
      ),
    );
  }

  // ── Sliver AppBar ──────────────────────────────────────
  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      pinned: true,
      automaticallyImplyLeading: false,
      // In RTL: leading widget appears on the RIGHT side (visually)
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(
          Icons.arrow_forward_ios_rounded, // RTL back arrow
          color: AppColors.textPrimary,
          size: 20,
        ),
      ),
      title: Text(
        widget.subjectName,
        style: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      // Sync button on the LEFT side (in RTL = actions side)
      actions: [
        RotationTransition(
          turns: _syncController,
          child: IconButton(
            onPressed: _onSync,
            icon: Icon(
              Icons.sync_rounded,
              color: _isSyncing
                  ? AppColors.primaryBlue
                  : AppColors.textSecondary,
              size: 26,
            ),
            tooltip: 'مزامنة',
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }

  // ── Grid ─────────────────────────────────────────────
  Widget _buildGrid() {
    return CustomScrollView(
      slivers: [
        // Subject info header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryBlue,
                        AppColors.primaryBlue.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.science_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subjectName,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'اختر قسماً للبدء',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 2-column grid of action cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => HubActionCard(
                action: _actions[index],
                onTap: () => _onActionTap(index),
              ),
              childCount: _actions.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.05, // nearly square cards
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── Navigation ────────────────────────────────────────
  void _onActionTap(int index) {
    HapticFeedback.selectionClick();
    switch (index) {
      case 0: // الامتحانات
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExamsListScreen(subjectName: widget.subjectName),
          ),
        );
        break;
      case 1: // التصنيفات
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TagsListScreen(subjectName: widget.subjectName),
          ),
        );
        break;
      case 4: // تدرب بنفسك
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TrainingSessionsScreen(subjectName: widget.subjectName),
          ),
        );
        break;
      case 2: // البحث
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchFilterScreen(
              subjectName: widget.subjectName,
              totalQuestions: 330,
            ),
          ),
        );
        break;
      case 5: // الإجابات الخاطئة
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WrongAnswersScreen(subjectName: widget.subjectName),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'قريباً: ${_actions[index].label}',
              style: GoogleFonts.cairo(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 1),
            backgroundColor: AppColors.textPrimary,
          ),
        );
    }
  }
}
