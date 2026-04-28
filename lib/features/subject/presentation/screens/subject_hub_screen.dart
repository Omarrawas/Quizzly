import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/subject/presentation/widgets/hub_action_card.dart';
import 'package:quizzly/features/quiz/presentation/screens/wrong_answers_screen.dart';
import 'package:quizzly/features/quiz/presentation/screens/practice_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/performance_screen.dart';
import 'package:quizzly/features/subject/presentation/screens/lists_screen.dart';
import 'package:quizzly/features/gamification/domain/services/gamification_service.dart';
import 'package:quizzly/features/gamification/data/models/gamification_profile.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';

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
  GamificationProfile? _profile;

  // ── الأزرار الستة المطلوبة ─────────────────────────────────────
  late final List<HubAction> _hubActions = [
    const HubAction(
      icon: Icons.assignment_rounded,
      label: 'الامتحانات',
      iconColor: Colors.white,
      iconBackground: Color(0xFF7C3AED),
    ),
    const HubAction(
      icon: Icons.category_rounded,
      label: 'التصنيفات',
      iconColor: Colors.white,
      iconBackground: Color(0xFF2563EB),
    ),
    const HubAction(
      icon: Icons.search_rounded,
      label: 'البحث',
      iconColor: Colors.white,
      iconBackground: Color(0xFF10B981),
    ),
    const HubAction(
      icon: Icons.favorite_rounded,
      label: 'المفضلة',
      iconColor: Colors.white,
      iconBackground: Color(0xFFEF4444),
    ),
    const HubAction(
      icon: Icons.error_outline_rounded,
      label: 'الإجابات الخاطئة',
      iconColor: Colors.white,
      iconBackground: Color(0xFFF59E0B),
    ),
    const HubAction(
      icon: Icons.fitness_center_rounded,
      label: 'تدرب بنفسك',
      iconColor: Colors.white,
      iconBackground: Color(0xFF6366F1),
    ),
  ];

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          
          // Header Stats Section
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

          // Main Actions Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => HubActionCard(
                  action: _hubActions[index],
                  onTap: () => _onActionTap(index),
                ),
                childCount: _hubActions.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      margin: const EdgeInsets.all(20),
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
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textPrimary, size: 20),
      ),
      title: Text(
        widget.subjectName,
        style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
      centerTitle: true,
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
        _showComingSoon('التصنيفات');
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
}
