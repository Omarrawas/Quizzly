import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/settings/presentation/screens/my_lists_screen.dart';
import 'package:quizzly/features/settings/presentation/screens/manage_codes_screen.dart';
import 'package:quizzly/features/settings/presentation/screens/settings_screen.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/auth/presentation/screens/splash_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'القائمة',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.menu_open_rounded,
                      color: AppColors.primaryBlue,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Menu Items ──────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.home_rounded,
                    label: 'الرئيسية',
                    isSelected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.notifications_none_rounded,
                    label: 'الإشعارات',
                    onTap: () {},
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.format_list_bulleted_rounded,
                    label: 'قوائمي',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListsScreen()));
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.code_rounded,
                    label: 'إدارة الأكواد',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCodesScreen()));
                    },
                  ),



                  // Admin Dashboard (Conditional)
                  if (context.watch<AuthService>().isAdmin)
                    _buildMenuItem(
                      context,
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'لوحة تحكم الأدمن',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                        );
                      },
                    ),

                  _buildMenuItem(
                    context,
                    icon: Icons.cloud_download_outlined,
                    label: 'إدارة التحميلات',
                    onTap: () {},
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    label: 'الإعدادات',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                ],
              ),
            ),

            // ── Footer ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Build Version: 0.4.4 (37)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ListTile(
                onTap: () async {
                  final authService = context.read<AuthService>();
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Theme.of(context).dialogTheme.backgroundColor ?? theme.colorScheme.surface,
                      title: Text('تسجيل الخروج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary)),
                      content: Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟', style: GoogleFonts.cairo(color: isDark ? Colors.white70 : AppColors.textSecondary)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('خروج', style: GoogleFonts.cairo(color: const Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await authService.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const SplashScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFDC2626),
                ),
                title: Text(
                  'تسجيل الخروج',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isSelected ? AppColors.primaryBlue : (isDark ? Colors.white : AppColors.textPrimary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: isSelected 
            ? (isDark ? AppColors.primaryBlue.withValues(alpha: 0.1) : const Color(0xFFEFF6FF)) 
            : Colors.transparent,
        leading: Icon(
          icon,
          color: primaryColor,
          size: 24,
        ),
        title: Text(
          label,
          style: GoogleFonts.cairo(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 15,
            color: primaryColor,
          ),
        ),
      ),
    );
  }
}
