import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/core/theme/theme_service.dart';
import 'package:quizzly/features/settings/domain/services/settings_service.dart';
import 'package:quizzly/features/settings/presentation/screens/user_profile_screen.dart';
import 'package:quizzly/features/auth/domain/services/auth_service.dart';
import 'package:quizzly/core/services/app_update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.user?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 26,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, userSnapshot) {
          Map<String, dynamic> defaults = {};
          String profilePicUrl = '';

          if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
            final data = userSnapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              defaults = data['defaults'] as Map<String, dynamic>? ?? {};
              profilePicUrl = data['profilePic'] as String? ?? '';
            }
          }

          final fullName = defaults['fullName'] as String? ?? '';
          final universityName = defaults['universityName'] as String? ?? 'جامعة حلب';
          final collegeName = defaults['collegeName'] as String? ?? 'كلية العلوم';
          final departmentName = defaults['departmentName'] as String? ?? 'كيمياء';
          final yearName = defaults['yearName'] as String? ?? 'السنة الثالثة';
          final universityId = defaults['universityId'] as String? ?? '20234567';

          final displayName = fullName.isNotEmpty ? fullName : 'طالب $universityName';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('practice_sessions')
                .where('userId', isEqualTo: userId)
                .snapshots(),
            builder: (context, sessionSnapshot) {
              final docs = sessionSnapshot.data?.docs ?? [];
              final completedExamsCount = docs.length;

              double totalScorePct = 0;
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final correct = (data['correctAnswers'] as num?)?.toDouble() ?? 0.0;
                final total = (data['totalQuestions'] as num?)?.toDouble() ?? 1.0;
                final pct = total > 0 ? (correct / total * 100) : 0.0;
                totalScorePct += pct;
              }
              final averageScore = completedExamsCount > 0 ? (totalScorePct / completedExamsCount) : 0.0;

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('user_gamification')
                    .doc(userId)
                    .snapshots(),
                builder: (context, gamificationSnapshot) {
                  int totalPoints = 0;
                  if (gamificationSnapshot.hasData && gamificationSnapshot.data!.exists) {
                    final gData = gamificationSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                    totalPoints = gData['xp'] as int? ?? 0;
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── 1. GORGEOUS USER PROFILE CARD ────────────────────────
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Avatar Container with Edit badge
                              Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF8B93FF).withValues(alpha: 0.6),
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8B93FF).withValues(alpha: 0.15),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 46,
                                      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                                      backgroundImage: profilePicUrl.isNotEmpty
                                          ? CachedNetworkImageProvider(profilePicUrl)
                                          : const CachedNetworkImageProvider(
                                              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
                                            ) as ImageProvider,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF8B93FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Display Name
                              Text(
                                displayName,
                                style: GoogleFonts.cairo(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              // Subtitle (ID & Academic Year)
                              Text(
                                'ID: $universityId • $yearName',
                                style: GoogleFonts.cairo(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 16),
                              // Badges row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildBadge(collegeName, isDark),
                                  const SizedBox(width: 8),
                                  _buildBadge(departmentName, isDark),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── 2. DYNAMIC STATS GRID ────────────────────────────────
                        Row(
                          children: [
                            // Completed Exams Card
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                height: 128,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Icon(
                                      Icons.assignment_outlined,
                                      color: Color(0xFF8B93FF),
                                      size: 26,
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$completedExamsCount',
                                          style: GoogleFonts.inter(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'اختباراً منجزاً',
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white54 : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Total Points Card
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                height: 128,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B93FF),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8B93FF).withValues(alpha: 0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Icon(
                                      Icons.emoji_events_rounded,
                                      color: Color(0xFF0F172A),
                                      size: 26,
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          NumberFormat('#,###').format(totalPoints),
                                          style: GoogleFonts.inter(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'إجمالي النقاط',
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── 3. AVERAGE MARKS ROW CARD ────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Progress slider details on the left
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${averageScore.round()}%',
                                          style: GoogleFonts.inter(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'متوسط العلامات',
                                          style: GoogleFonts.cairo(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white60 : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: averageScore / 100,
                                        minHeight: 7.5,
                                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B93FF)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              // Trend Up Icon inside custom red/pink container on the right
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF3B1E30)
                                      : const Color(0xFFFFF1F4),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.trending_up_rounded,
                                  color: Color(0xFFFF527B),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── 4. SETTINGS & PREFERENCES SECTION ────────────────────
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'الإعدادات والتفضيلات',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Account Settings item
                        _buildSettingsTile(
                          context: context,
                          title: 'إعدادات الحساب',
                          icon: Icons.person_outline_rounded,
                          isDark: isDark,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                            );
                          },
                        ),

                        // Dark Mode item
                        Consumer<ThemeService>(
                          builder: (context, themeService, _) {
                            final isThemeDark = themeService.themeMode == ThemeMode.dark;
                            return _buildSettingsTile(
                              context: context,
                              title: 'الوضع الداكن',
                              icon: Icons.nightlight_round_outlined,
                              isDark: isDark,
                              trailing: Switch(
                                value: isThemeDark,
                                onChanged: (val) => themeService.toggleTheme(),
                                activeThumbColor: const Color(0xFF0F172A),
                                activeTrackColor: const Color(0xFF8B93FF),
                                inactiveThumbColor: Colors.grey[400],
                                inactiveTrackColor: Colors.grey[300],
                              ),
                            );
                          },
                        ),

                        // Study & App Settings item (PRESERVING COMPLETED PREFERENCES LIST)
                        _buildSettingsTile(
                          context: context,
                          title: 'إعدادات الدراسة والتطبيق',
                          icon: Icons.tune_rounded,
                          isDark: isDark,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StudyPreferencesScreen()),
                            );
                          },
                        ),

                        // Technical Support item
                        _buildSettingsTile(
                          context: context,
                          title: 'الدعم الفني',
                          icon: Icons.headset_mic_outlined,
                          isDark: isDark,
                          onTap: () => _launchSupportBot(context),
                        ),

                        // Logout item
                        _buildSettingsTile(
                          context: context,
                          title: 'تسجيل الخروج',
                          icon: Icons.logout_rounded,
                          isDark: isDark,
                          textColor: const Color(0xFFFF7E67),
                          iconColor: const Color(0xFFFF7E67),
                          hasChevron: false,
                          onTap: () => _handleLogout(context, auth),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBadge(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E3B4E).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white.withValues(alpha: 0.87) : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isDark,
    Color? textColor,
    Color? iconColor,
    bool hasChevron = true,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
          width: 1.2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Icon(
          icon,
          color: iconColor ?? (isDark ? Colors.white70 : AppColors.textPrimary),
          size: 23,
        ),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: textColor ?? (isDark ? Colors.white : AppColors.textPrimary),
          ),
        ),
        trailing: trailing ?? (hasChevron
            ? Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14,
                color: isDark ? Colors.white30 : Colors.grey[300],
              )
            : null),
      ),
    );
  }

  Future<void> _launchSupportBot(BuildContext context) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('settings').doc('socials').get();
      String supportBotUrl = 'https://t.me/QuizzlySupportBot';
      if (snap.exists) {
        final data = snap.data();
        if (data != null && data['supportBotUrl'] != null) {
          supportBotUrl = data['supportBotUrl'] as String;
        }
      }
      final Uri url = Uri.parse(supportBotUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch support URL';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح الدعم الفني: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context, AuthService auth) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تسجيل الخروج',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimary,
          ),
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
          style: GoogleFonts.cairo(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textSecondary,
          ),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'خروج',
              style: GoogleFonts.cairo(
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await auth.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
      }
    }
  }
}

// ── STUDY PREFERENCES SCREEN widget (Preserves existing advanced study details) ──
class StudyPreferencesScreen extends StatelessWidget {
  const StudyPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'إعدادات الدراسة والتطبيق',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          final auth = Provider.of<AuthService>(context, listen: false);
          final userId = auth.user?.uid ?? '';

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // ── Study Experience Settings
              _buildHeaderSection('تجربة الدراسة', Icons.menu_book_rounded, isDark),
              _buildSelectionRowTile(
                title: 'حجم النص',
                subtitle: 'تعديل حجم النصوص المعروضة في شاشات الأسئلة',
                trailingText: settings.textSize == 'smaller'
                    ? 'أصغر'
                    : settings.textSize == 'larger'
                        ? 'أكبر'
                        : settings.textSize == 'very_large'
                            ? 'كبير جداً'
                            : 'الحجم الافتراضي',
                icon: Icons.format_size_rounded,
                onTap: () => _showTextSizeSelectionDialog(context, settings),
                isDark: isDark,
              ),
              _buildSelectionRowTile(
                title: 'مدة عرض الملاحظات',
                subtitle: 'مدة عرض ملاحظات الطلاب المحفوظة في شاشة الاختبار',
                trailingText: settings.notesDisplayDuration == -1
                    ? 'ثابتة'
                    : '${settings.notesDisplayDuration} ث',
                icon: Icons.speaker_notes_rounded,
                onTap: () => _showSingleSelectionDialog<int>(
                  context,
                  'مدة عرض الملاحظات',
                  [-1, 3, 5, 10],
                  settings.notesDisplayDuration,
                  settings.setNotesDisplayDuration,
                  (v) => v == -1 ? 'ثابتة' : '$v ثواني',
                ),
                isDark: isDark,
              ),
              _buildSelectionRowTile(
                title: 'مدة عرض الشرح',
                subtitle: 'مدة عرض شريط توضيح الإجابة التلقائي',
                trailingText: settings.explanationDisplayDuration == -1
                    ? 'ثابتة'
                    : '${settings.explanationDisplayDuration} ث',
                icon: Icons.assignment_turned_in_rounded,
                onTap: () => _showSingleSelectionDialog<int>(
                  context,
                  'مدة عرض الشرح',
                  [-1, 3, 5, 10],
                  settings.explanationDisplayDuration,
                  settings.setExplanationDisplayDuration,
                  (v) => v == -1 ? 'ثابتة' : '$v ثواني',
                ),
                isDark: isDark,
              ),
              _buildSwitchRowTile(
                title: 'تحميل أثناء التشغيل',
                subtitle: 'تحميل الفيديوهات تلقائياً أثناء تشغيلها',
                value: settings.loadWhilePlaying,
                onChanged: settings.setLoadWhilePlaying,
                isDark: isDark,
              ),
              _buildSelectionRowTile(
                title: 'مقدار القفز في الفيديو',
                subtitle: 'مقدار القفز للأمام أو للخلف في الفيديوهات التعليمية',
                trailingText: '${settings.skipDuration} ث',
                icon: Icons.fast_forward_rounded,
                onTap: () => _showSingleSelectionDialog<int>(
                  context,
                  'مقدار القفز في الفيديو',
                  [5, 10, 15, 30, 60],
                  settings.skipDuration,
                  settings.setSkipDuration,
                  (v) => '$v ثانية',
                ),
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // ── Content Organization
              _buildHeaderSection('تنظيم المحتوى', Icons.sort_rounded, isDark),
              _buildSwitchRowTile(
                title: 'تثبيت آخر مادة مفتوحة',
                subtitle: 'عرض آخر مادة تم فتحها في أعلى القائمة الرئيسية',
                value: settings.pinLastSubject,
                onChanged: settings.setPinLastSubject,
                isDark: isDark,
              ),
              _buildSwitchRowTile(
                title: 'عرض حلولي والموضع الأخير',
                subtitle: 'مزامنة حلولك وموضعك الأخير في المواد',
                value: settings.showMySolutions,
                onChanged: settings.setShowMySolutions,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // ── Updates and Content Data
              _buildHeaderSection('التحديثات وبيانات المحتوى', Icons.sync_rounded, isDark),
              _buildSelectionRowTile(
                title: 'فترة التحديث التلقائي',
                subtitle: 'التحقق التلقائي من التحديثات كل عدة دقائق',
                trailingText: '${settings.autoUpdateInterval} د',
                icon: Icons.access_time_rounded,
                onTap: () => _showSingleSelectionDialog(
                  context,
                  'فترة التحديث التلقائي',
                  [5, 10, 30, 60, 120],
                  settings.autoUpdateInterval,
                  settings.setAutoUpdateInterval,
                  (v) => '$v دقيقة',
                ),
                isDark: isDark,
              ),
              _buildActionRowTile(
                title: 'إعادة تحميل بيانات المواد',
                subtitle: 'تحديث وتنزيل بيانات المواد والأسئلة من السحابة',
                icon: Icons.refresh_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('جاري إعادة تحميل البيانات...'),
                    ),
                  );
                },
                isDark: isDark,
              ),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '...';
                  final buildNumber = snapshot.data?.buildNumber ?? '';
                  return _buildActionRowTile(
                    title: 'التحقق من وجود تحديث',
                    subtitle: 'الإصدار الحالي: $version ($buildNumber) - اضغط للتحقق',
                    icon: Icons.system_update_rounded,
                    onTap: () => AppUpdateService().checkForUpdates(
                      context,
                      showNoUpdateDialog: true,
                    ),
                    isDark: isDark,
                  );
                },
              ),
              const SizedBox(height: 16),

              // ── User Data
              _buildHeaderSection('بيانات المستخدم', Icons.admin_panel_settings_rounded, isDark),
              _buildActionRowTile(
                title: 'حذف بيانات مادة محددة',
                subtitle: 'إزالة سجلات الحلول لمادة معينة',
                icon: Icons.delete_outline_rounded,
                onTap: () => _handleDeleteSubjectProgress(context, userId),
                isDark: isDark,
              ),
              _buildActionRowTile(
                title: 'نسخ معلومات الجهاز',
                subtitle: 'نسخ المعرّفات التقنية لمشاركتها مع الدعم الفني',
                icon: Icons.copy_rounded,
                onTap: () => _handleCopyDeviceInfo(context, userId),
                isDark: isDark,
              ),
              _buildActionRowTile(
                title: 'حذف الحساب',
                subtitle: 'سيتم حذف حسابك وجميع بياناتك نهائياً من السحابة',
                icon: Icons.person_off_rounded,
                isDestructive: true,
                onTap: () => _handleDeleteAccount(context, auth),
                isDark: isDark,
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDark ? const Color(0xFF8B93FF) : AppColors.primaryBlue,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRowTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF8B93FF),
        activeTrackColor: const Color(0xFF8B93FF).withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.cairo(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionRowTile({
    required String title,
    required String subtitle,
    required String trailingText,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.cairo(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
        ),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            trailingText,
            style: GoogleFonts.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF8B93FF) : AppColors.primaryBlue,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 13,
          color: isDark ? Colors.white24 : Colors.grey[300],
        ),
      ),
    );
  }

  Widget _buildActionRowTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
    required bool isDark,
  }) {
    final titleColor = isDestructive ? const Color(0xFFEF4444) : (isDark ? Colors.white : AppColors.textPrimary);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.cairo(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
        ),
        leading: Icon(
          icon,
          color: isDestructive ? titleColor : (isDark ? Colors.white38 : AppColors.textSecondary),
          size: 22,
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 13,
          color: isDark ? Colors.white24 : Colors.grey[300],
        ),
      ),
    );
  }

  // Helper dialogs
  void _showSingleSelectionDialog<T>(
    BuildContext context,
    String title,
    List<T> options,
    T currentValue,
    Function(T) onSelected,
    String Function(T) labelBuilder,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final isSelected = opt == currentValue;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF8B93FF).withValues(alpha: isDark ? 0.15 : 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  labelBuilder(opt),
                  style: GoogleFonts.cairo(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? (isDark ? const Color(0xFF8B93FF) : AppColors.primaryBlue)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  textAlign: TextAlign.center,
                ),
                onTap: () {
                  onSelected(opt);
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTextSizeSelectionDialog(BuildContext context, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentValue = settings.textSize;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'حجم خط النصوص',
          style: GoogleFonts.cairo(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextSizeOption(
                  context: context,
                  settings: settings,
                  value: 'smaller',
                  title: 'أصغر (85%)',
                  scaleFactor: 0.85,
                  isSelected: currentValue == 'smaller',
                  isDark: isDark,
                ),
                _buildTextSizeOption(
                  context: context,
                  settings: settings,
                  value: 'default',
                  title: 'الحجم الافتراضي (100%)',
                  scaleFactor: 1.0,
                  isSelected: currentValue == 'default',
                  isDark: isDark,
                ),
                _buildTextSizeOption(
                  context: context,
                  settings: settings,
                  value: 'larger',
                  title: 'أكبر (115%)',
                  scaleFactor: 1.15,
                  isSelected: currentValue == 'larger',
                  isDark: isDark,
                ),
                _buildTextSizeOption(
                  context: context,
                  settings: settings,
                  value: 'very_large',
                  title: 'كبير جداً (135%)',
                  scaleFactor: 1.35,
                  isSelected: currentValue == 'very_large',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextSizeOption({
    required BuildContext context,
    required SettingsService settings,
    required String value,
    required String title,
    required double scaleFactor,
    required bool isSelected,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF8B93FF).withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF8B93FF) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          settings.setTextSize(value);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isSelected ? const Color(0xFF8B93FF) : (isDark ? Colors.white : AppColors.textPrimary),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF8B93FF),
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'هذا مثال لنص السؤال او الشرح كما سيظهر في التطبيق',
                  style: GoogleFonts.cairo(
                    fontSize: 13 * scaleFactor,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Deletion and copying handlers
  Future<void> _handleDeleteSubjectProgress(BuildContext context, String userId) async {
    final db = FirebaseFirestore.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى تسجيل الدخول أولاً.',
            style: GoogleFonts.cairo(),
            textAlign: TextAlign.right,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final activeSubsSnap = await db.collection('user_subjects').where('userId', isEqualTo: userId).get();

      if (!context.mounted) return;
      Navigator.pop(context); // Remove loading indicator

      if (activeSubsSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا توجد مواد مفعّلة حالياً لحذف بياناتها.',
              style: GoogleFonts.cairo(),
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final List<Map<String, String>> subjectsList = [];
      for (var doc in activeSubsSnap.docs) {
        final subjectId = doc.data()['subjectId'] as String;
        final subDoc = await db.collection('subjects').doc(subjectId).get();
        if (subDoc.exists) {
          final title = subDoc.data()?['title'] ?? 'مادة غير معروفة';
          subjectsList.add({'id': subjectId, 'title': title});
        } else {
          subjectsList.add({'id': subjectId, 'title': subjectId});
        }
      }

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'حذف بيانات مادة محددة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: subjectsList.length,
              itemBuilder: (context, index) {
                final sub = subjectsList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      sub['title']!,
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: isDark ? Colors.white30 : Colors.grey,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDeleteSubjectProgress(context, userId, sub['id']!, sub['title']!);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء جلب المواد: $e')));
      }
    }
  }

  void _confirmDeleteSubjectProgress(
    BuildContext context,
    String userId,
    String subjectId,
    String subjectTitle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف جميع سجلات الحلول، المفضلة، وسجل الإعادة المتباعدة الخاصة بمادة "$subjectTitle"؟ لا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final db = FirebaseFirestore.instance;

                final userHistoryDoc = db.collection('user_history').doc(userId);
                final userHistorySnap = await userHistoryDoc.get();
                if (userHistorySnap.exists) {
                  await userHistoryDoc.update({
                    'wrongAnswers_$subjectId': FieldValue.delete(),
                    'correctAnswers_$subjectId': FieldValue.delete(),
                    'solvedQuestions_$subjectId': FieldValue.delete(),
                    'skippedQuestions_$subjectId': FieldValue.delete(),
                  });
                }

                final practiceSessions = await db
                    .collection('practice_sessions')
                    .where('userId', isEqualTo: userId)
                    .where('subjectId', isEqualTo: subjectId)
                    .get();
                for (var doc in practiceSessions.docs) {
                  await doc.reference.delete();
                }

                final favorites = await db
                    .collection('users')
                    .doc(userId)
                    .collection('user_lists')
                    .doc('favorites')
                    .collection('questions')
                    .where('questionData.subjectId', isEqualTo: subjectId)
                    .get();
                for (var doc in favorites.docs) {
                  await doc.reference.delete();
                }

                final mastery = await db
                    .collection('users')
                    .doc(userId)
                    .collection('mastery')
                    .where('subjectId', isEqualTo: subjectId)
                    .get();
                for (var doc in mastery.docs) {
                  await doc.reference.delete();
                }

                if (!context.mounted) return;
                Navigator.pop(context); // Close loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم مسح سجل الحلول لمادة $subjectTitle بنجاح',
                      style: GoogleFonts.cairo(),
                      textAlign: TextAlign.right,
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'نعم، احذف',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount(BuildContext context, AuthService auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'حذف الحساب نهائياً',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
          ],
        ),
        content: Text(
          'تحذير: سيتم حذف حسابك وجميع بياناتك (سجل الحلول، الملاحظات، المفضلة، الكود الفعّال، والرصيد) بشكل نهائي ولا يمكن استرجاعها. هل أنت متأكد من رغبتك في حذف الحساب؟',
          style: GoogleFonts.cairo(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              final success = await auth.deleteAccount();
              if (!context.mounted) return;
              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حذف الحساب بنجاح. سنفتقدك!',
                      style: GoogleFonts.cairo(),
                      textAlign: TextAlign.right,
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      auth.errorMessage ?? 'فشل في حذف الحساب.',
                      style: GoogleFonts.cairo(),
                      textAlign: TextAlign.right,
                    ),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'نعم، احذف الحساب',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCopyDeviceInfo(BuildContext context, String? uid) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final email = FirebaseAuth.instance.currentUser?.email ?? 'omar.rawas17@gmail.com';

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String platform = 'unknown';
    String deviceName = 'unknown';
    String model = 'unknown';
    String brand = 'unknown';
    String system = 'unknown';
    String uniqueId = 'unknown';
    String androidId = 'unknown';
    String fingerprint = 'unknown';
    String buildId = 'unknown';

    if (kIsWeb) {
      final webBrowserInfo = await deviceInfo.webBrowserInfo;
      platform = 'web';
      deviceName = webBrowserInfo.browserName.toString();
      model = 'Web Browser';
      brand = 'Web';
      system = webBrowserInfo.appVersion ?? 'Unknown';
      uniqueId = 'web_session';
      androidId = 'web_session';
      fingerprint = 'web|browser';
      buildId = 'web_build';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      platform = 'android';
      deviceName = androidInfo.device;
      model = androidInfo.model;
      brand = androidInfo.brand;
      system = 'Android ${androidInfo.version.release}';
      uniqueId = androidInfo.id;
      androidId = androidInfo.id;
      fingerprint = "${androidInfo.id}|${androidInfo.model}|${androidInfo.brand}|Android";
      buildId = androidInfo.display;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      platform = 'ios';
      deviceName = iosInfo.name;
      model = iosInfo.model;
      brand = 'Apple';
      system = 'iOS ${iosInfo.systemVersion}';
      uniqueId = iosInfo.identifierForVendor ?? 'unknown_ios';
      androidId = iosInfo.identifierForVendor ?? 'unknown_ios';
      fingerprint = "${iosInfo.identifierForVendor}|${iosInfo.model}|Apple|iOS";
      buildId = 'ios_build';
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      platform = 'windows';
      deviceName = windowsInfo.computerName;
      model = 'PC';
      brand = 'Windows PC';
      system = 'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
      uniqueId = 'windows_pc';
      androidId = 'windows_pc';
      fingerprint = "windows|PC";
      buildId = 'windows_build';
    }

    final String infoText = """Device Information:
App Version: ${packageInfo.version} (${packageInfo.buildNumber})
Signed-in Email: $email
Platform: $platform
Device Name: $deviceName
Model: $model
Brand: $brand
System: $system
Unique ID: $uniqueId
Android ID: $androidId
Fingerprint: $fingerprint
Build ID: $buildId""";

    await Clipboard.setData(ClipboardData(text: infoText));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ معلومات الجهاز الفنية إلى الحافظة بنجاح.',
          style: GoogleFonts.cairo(),
          textAlign: TextAlign.right,
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
}
