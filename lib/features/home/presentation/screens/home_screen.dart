import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/home/data/models/college_model.dart';
import 'package:quizzly/features/home/presentation/widgets/activation_sheets.dart';
import 'package:quizzly/features/subject/presentation/screens/subject_hub_screen.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/theme_service.dart';
import 'package:quizzly/features/home/presentation/widgets/app_drawer.dart';
import 'package:quizzly/features/home/presentation/screens/subject_selection_screen.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/home/domain/services/college_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // ─── Activation Flow ───────────────────────────────────
  void _openActivationFlow() {
    _showStep1();
  }

  void _showStep1() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivationStep1Sheet(
        onContinueWithoutCode: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubjectSelectionScreen()),
          );
        },
        onAddCode: () {
          Navigator.pop(context);
          _showStep2();
        },
      ),
    );
  }

  void _showStep2() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivationStep2Sheet(
        onBack: () {
          Navigator.pop(context);
          _showStep1();
        },
        onNext: (code) {
          Navigator.pop(context);
          _showStep3(code);
        },
      ),
    );
  }

  void _showStep3(String code) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivationStep3Sheet(
        code: code,
        onBack: () {
          Navigator.pop(context);
          _showStep2();
        },
        onActivated: () {
          Navigator.pop(context);
          _showSuccessSnackBar('تم تفعيل الكود بنجاح! 🎉');
        },
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final collegeService = context.read<CollegeService>();
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(),
      body: authService.user == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<CollegeModel>>(
              stream: collegeService.getUserColleges(authService.user!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final colleges = snapshot.data ?? [];
                
                return _buildBody(colleges);
              },
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.appBarTheme.backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: Icon(
            Icons.menu_rounded,
            color: theme.brightness == Brightness.light ? AppColors.textPrimary : Colors.white,
            size: 28,
          ),
        ),
      ),
      title: Text(
        'تطبيق كويزلي',
        style: GoogleFonts.cairo(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: theme.brightness == Brightness.light ? AppColors.textPrimary : Colors.white,
        ),
      ),
      centerTitle: false,
      actions: [
        Consumer<ThemeService>(
          builder: (context, themeService, _) {
            final isLight = themeService.themeMode == ThemeMode.light;
            return IconButton(
              onPressed: themeService.toggleTheme,
              icon: Icon(
                isLight ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                color: Theme.of(context).brightness == Brightness.light 
                    ? AppColors.textSecondary 
                    : Colors.white,
                size: 24,
              ),
              tooltip: 'المظهر',
            );
          },
        ),
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFFF8500),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.download_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(List<CollegeModel> colleges) {
    return CustomScrollView(
      slivers: [
        colleges.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 80,
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا يوجد كليات مضافة بعد',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط على زر + لإضافة كليتك والبدء في الدراسة',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => PremiumCourseCard(
                      college: colleges[index],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubjectHubScreen(
                                subjectName: colleges[index].name),
                          ),
                        );
                      },
                    ),
                    childCount: colleges.length,
                  ),
                ),
              ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _openActivationFlow,
      backgroundColor: AppColors.primaryBlue,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
    );
  }
}

// ─────────────────────────────────────────
//  Premium Course Card Widget
// ─────────────────────────────────────────
class PremiumCourseCard extends StatelessWidget {
  final CollegeModel college;
  final VoidCallback onTap;

  const PremiumCourseCard({
    super.key,
    required this.college,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.light 
                ? Colors.black.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 1. Controls (Right in RTL)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primaryBlue,
                    size: 26,
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.error_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // 2. Info Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      college.name,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      college.subtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '04/04/2026',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _miniBadge(
                          'ديمو',
                          const Color(0xFF16A34A),
                          const Color(0xFFE6F4EA),
                          Icons.star_rounded,
                        ),
                        const SizedBox(width: 8),
                        _miniBadge(
                          '${college.subjectCount} مادة',
                          const Color(0xFF2563EB),
                          const Color(0xFFE8F0FE),
                          Icons.collections_bookmark_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 3. Purple Icon (Left in RTL)
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFF633AFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
