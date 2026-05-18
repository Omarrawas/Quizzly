import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/settings/presentation/screens/my_lists_screen.dart';
import 'package:quizzly/features/settings/presentation/screens/manage_codes_screen.dart';
import 'package:quizzly/features/settings/presentation/screens/download_management_screen.dart';
import 'package:quizzly/features/settings/presentation/screens/settings_screen.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/features/auth/presentation/screens/splash_screen.dart';
import 'package:quizzly/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/features/home/presentation/screens/notifications_screen.dart';
import 'package:quizzly/features/settings/presentation/screens/wallet_screen.dart';
import 'package:quizzly/features/settings/presentation/screens/sales_locations_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('settings').doc('socials').snapshots(),
          builder: (context, snapshot) {
            final socialsData = snapshot.data?.data() as Map<String, dynamic>? ?? {};

            final supportBotUrl = socialsData['supportBotUrl'] as String? ?? 'https://t.me/QuizzlySupportBot';

            final telegramUrl = socialsData['telegramUrl'] as String? ?? 'https://t.me/QuizzlyChannel';
            final telegramEnabled = socialsData['telegramEnabled'] as bool? ?? true;

            final whatsappUrl = socialsData['whatsappUrl'] as String? ?? 'https://wa.me/963955555555';
            final whatsappEnabled = socialsData['whatsappEnabled'] as bool? ?? true;

            final youtubeUrl = socialsData['youtubeUrl'] as String? ?? 'https://youtube.com/';
            final youtubeEnabled = socialsData['youtubeEnabled'] as bool? ?? true;

            final facebookUrl = socialsData['facebookUrl'] as String? ?? 'https://facebook.com/';
            final facebookEnabled = socialsData['facebookEnabled'] as bool? ?? true;

            final instagramUrl = socialsData['instagramUrl'] as String? ?? 'https://instagram.com/';
            final instagramEnabled = socialsData['instagramEnabled'] as bool? ?? true;

            // Build dynamic footer buttons
            final List<Widget> socialButtons = [];
            if (telegramEnabled) {
              socialButtons.add(_buildSocialButton(
                icon: Icons.telegram_rounded,
                color: const Color(0xFF0088CC),
                onTap: () => _launchURL(context, telegramUrl),
              ));
            }
            if (whatsappEnabled) {
              socialButtons.add(_buildSocialButton(
                icon: Icons.chat_rounded,
                color: const Color(0xFF25D366),
                onTap: () => _launchURL(context, whatsappUrl),
              ));
            }
            if (youtubeEnabled) {
              socialButtons.add(_buildSocialButton(
                icon: Icons.play_circle_fill_rounded,
                color: const Color(0xFFFF0000),
                onTap: () => _launchURL(context, youtubeUrl),
              ));
            }
            if (facebookEnabled) {
              socialButtons.add(_buildSocialButton(
                icon: Icons.facebook_rounded,
                color: const Color(0xFF1877F2),
                onTap: () => _launchURL(context, facebookUrl),
              ));
            }
            if (instagramEnabled) {
              socialButtons.add(_buildSocialButton(
                icon: Icons.camera_alt_rounded,
                color: const Color(0xFFE1306C),
                onTap: () => _launchURL(context, instagramUrl),
              ));
            }

            // Add spacing between footer items
            final List<Widget> spacedSocialButtons = [];
            for (int i = 0; i < socialButtons.length; i++) {
              spacedSocialButtons.add(socialButtons[i]);
              if (i < socialButtons.length - 1) {
                spacedSocialButtons.add(const SizedBox(width: 12));
              }
            }

            return Column(
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
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                        },
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
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'محفظتي',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.location_on_rounded,
                        label: 'أماكن بيع أكواد الرصيد',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesLocationsScreen()));
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.code_rounded,
                        label: 'إدارة الاشتراكات',
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
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadManagementScreen()));
                        },
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

                      const SizedBox(height: 16),

                      // ── Telegram Technical Support Card ──
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0088CC), Color(0xFF24A1DE)],
                            begin: Alignment.bottomRight,
                            end: Alignment.topLeft,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0088CC).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _launchURL(context, supportBotUrl),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.headset_mic_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'الدعم الفني المباشر',
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'تواصل معنا مباشرة عبر تلغرام',
                                          style: GoogleFonts.cairo(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Footer ──────────────────────────────────────
                if (spacedSocialButtons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: spacedSocialButtons,
                      ),
                    ),
                  ),

                // ── Version Info ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.data?.version ?? '...';
                      final buildNumber = snapshot.data?.buildNumber ?? '';
                      return Text(
                        'Build Version: $version ($buildNumber)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),

                // ── Logout Button ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
            );
          },
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

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح الرابط: $urlString', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 22,
        ),
      ),
    );
  }
}
