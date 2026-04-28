import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/theme/theme_service.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/home/domain/services/content_service.dart';
import 'package:quizzly/features/home/presentation/widgets/app_drawer.dart';
import 'package:quizzly/features/home/presentation/widgets/subject_card.dart';
import 'package:quizzly/features/subject/presentation/screens/subject_hub_screen.dart';
import 'package:quizzly/features/home/presentation/screens/subject_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  void _openActivationFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubjectSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final contentService = context.read<ContentService>();
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(),
      body: authService.user == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: contentService.getUserActiveSubjects(authService.user!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final subjects = snapshot.data ?? [];
                
                return _buildBody(subjects);
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

  Widget _buildBody(List<Map<String, dynamic>> subjects) {
    return CustomScrollView(
      slivers: [
        subjects.isEmpty
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
                        'لا يوجد مواد مضافة بعد',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط على زر + لإضافة مواد والبدء في الدراسة',
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
                    (context, index) => SubjectCard(
                      subject: subjects[index],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubjectHubScreen(
                              subjectId: subjects[index]['id'],
                              subjectName: subjects[index]['name'],
                            ),
                          ),
                        );
                      },
                    ),
                    childCount: subjects.length,
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
